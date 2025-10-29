import Foundation
import SwiftUI
import Security
#if canImport(UIKit)
import UIKit
#else
import ImageIO
import MobileCoreServices
#endif

/// Google Cloud Vision OCR integration supporting either an API key (Keychain service `com.mortgageguardian.api.googlevision`)
/// or a service account JSON stored in Keychain under `com.mortgageguardian.api.google_service_account`.
/// If a service account is present, the service will mint a short-lived OAuth2 access token using a signed JWT.
@Observable
class GoogleCloudOCRService {
    enum GoogleOCRError: Error {
        case missingAPIKeyOrServiceAccount
        case encodingFailed
        case networkError(Error)
        case invalidResponse
        case tokenSigningFailed
        case invalidServiceAccount
    }

    private let apiKeyService = "com.mortgageguardian.api.googlevision"
    private let serviceAccountService = "com.mortgageguardian.api.google_service_account"
    private let tokenServerService = "com.mortgageguardian.api.token_server_url"

    // Simple in-memory cache for the access token
    private var cachedAccessToken: String?
    private var tokenExpiry: Date?

    func analyzeImage(_ image: CGImage, languageHints: [String] = ["en"]) async throws -> String {
        // Convert CGImage to JPEG data
        let jpegData: Data
        #if canImport(UIKit)
        guard let uiImage = UIImage(cgImage: image),
              let d = uiImage.jpegData(compressionQuality: 0.8) else {
            throw GoogleOCRError.encodingFailed
        }
        jpegData = d
        #else
        guard let data = CFDataCreateMutable(nil, 0) else { throw GoogleOCRError.encodingFailed }
        guard let dest = CGImageDestinationCreateWithData(data, kUTTypeJPEG, 1, nil) else { throw GoogleOCRError.encodingFailed }
        CGImageDestinationAddImage(dest, image, nil)
        if !CGImageDestinationFinalize(dest) { throw GoogleOCRError.encodingFailed }
        jpegData = data as Data
        #endif

        let base64 = jpegData.base64EncodedString()

        // Request body
        let requestBody: [String: Any] = [
            "requests": [
                [
                    "image": ["content": base64],
                    "features": [["type": "DOCUMENT_TEXT_DETECTION", "maxResults": 1]],
                    "imageContext": ["languageHints": languageHints]
                ]
            ]
        ]

        // Prefer a token server (recommended): if a token server URL is stored in Keychain, fetch a token from it
        if let tokenServerURL = try? SecureKeyManager.shared.getAPIKey(forService: tokenServerService) {
            if let token = try await fetchTokenFromTokenServer(urlString: tokenServerURL) {
                return try await callVisionAnnotate(withRequestBody: requestBody, authorizationToken: token)
            }
            // If token server fails, continue to try local service-account or API key
        }

        // Try service account -> OAuth flow next (device-side minting). Use only for testing or controlled environments.
        if let serviceAccountJSON = try? SecureKeyManager.shared.getAPIKey(forService: serviceAccountService) {
            if let token = try await getAccessToken(fromServiceAccountJSON: serviceAccountJSON) {
                // Use OAuth token in Authorization header
                return try await callVisionAnnotate(withRequestBody: requestBody, authorizationToken: token)
            }
            // If token creation fails, fall through to API key path
        }

        // Fallback: API key path
        if let apiKey = try? SecureKeyManager.shared.getAPIKey(forService: apiKeyService) {
            return try await callVisionAnnotate(withRequestBody: requestBody, apiKey: apiKey)
        }

        throw GoogleOCRError.missingAPIKeyOrServiceAccount
    }

    // MARK: - Networking helpers

    private func callVisionAnnotate(withRequestBody body: [String: Any], apiKey: String? = nil, authorizationToken: String? = nil) async throws -> String {
        var url: URL
        if let key = apiKey {
            guard let u = URL(string: "https://vision.googleapis.com/v1/images:annotate?key=\(key)") else { throw GoogleOCRError.invalidResponse }
            url = u
        } else {
            guard let u = URL(string: "https://vision.googleapis.com/v1/images:annotate") else { throw GoogleOCRError.invalidResponse }
            url = u
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let token = authorizationToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
                throw GoogleOCRError.invalidResponse
            }

            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let responses = json["responses"] as? [[String: Any]],
                  let first = responses.first else {
                throw GoogleOCRError.invalidResponse
            }

            if let fullText = first["fullTextAnnotation"] as? [String: Any], let text = fullText["text"] as? String {
                return text
            }

            if let textAnns = first["textAnnotations"] as? [[String: Any]], let firstAnn = textAnns.first, let desc = firstAnn["description"] as? String {
                return desc
            }

            return ""
        } catch {
            throw GoogleOCRError.networkError(error)
        }
    }

    // MARK: - Token server helper

    private func fetchTokenFromTokenServer(urlString: String) async throws -> String? {
        guard let url = URL(string: urlString) else { return nil }

        let fetch = {
            var req = URLRequest(url: url)
            req.httpMethod = "POST"
            req.setValue("application/json", forHTTPHeaderField: "Accept")
            return try await URLSession.shared.data(for: req)
        }

        // Simple retry with backoff
        var attempt = 0
        var lastError: Error?
        while attempt < 3 {
            do {
                let (data, response) = try await fetch()
                guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
                    lastError = GoogleOCRError.invalidResponse
                    attempt += 1
                    try await Task.sleep(nanoseconds: UInt64(200_000_000 * UInt64(attempt)))
                    continue
                }

                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any], let token = json["access_token"] as? String {
                    return token
                }

                lastError = GoogleOCRError.invalidResponse
                attempt += 1
                try await Task.sleep(nanoseconds: UInt64(200_000_000 * UInt64(attempt)))
            } catch {
                lastError = error
                attempt += 1
                // exponential backoff with jitter
                let base: UInt64 = 150_000_000
                let jitter = UInt64.random(in: 0...50_000_000)
                try await Task.sleep(nanoseconds: base * UInt64(attempt) + jitter)
            }
        }

        if let err = lastError { throw err }
        return nil
    }

    // MARK: - Service account JWT / token exchange

    private func getAccessToken(fromServiceAccountJSON jsonString: String) async throws -> String? {
        // Return cached token if still valid
        if let token = cachedAccessToken, let expiry = tokenExpiry, expiry > Date().addingTimeInterval(30) {
            return token
        }

        guard let data = jsonString.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let clientEmail = json["client_email"] as? String,
              let privateKeyPEM = json["private_key"] as? String,
              let tokenURI = json["token_uri"] as? String else {
            throw GoogleOCRError.invalidServiceAccount
        }

        let now = Int(Date().timeIntervalSince1970)
        let exp = now + 3600 // 1 hour

        let header: [String: Any] = ["alg": "RS256", "typ": "JWT"]
        let claims: [String: Any] = [
            "iss": clientEmail,
            "scope": "https://www.googleapis.com/auth/cloud-platform",
            "aud": tokenURI,
            "exp": exp,
            "iat": now
        ]

        func base64URLEncode(_ data: Data) -> String {
            var s = data.base64EncodedString()
            s = s.replacingOccurrences(of: "+", with: "-")
            s = s.replacingOccurrences(of: "/", with: "_")
            s = s.replacingOccurrences(of: "=", with: "")
            return s
        }

        let headerData = try JSONSerialization.data(withJSONObject: header)
        let claimsData = try JSONSerialization.data(withJSONObject: claims)
        let signingInput = "\(base64URLEncode(headerData)).\(base64URLEncode(claimsData))"

        guard let signature = try signJWT(signingInput: signingInput, privateKeyPEM: privateKeyPEM) else {
            throw GoogleOCRError.tokenSigningFailed
        }

        let jwt = signingInput + "." + signature

        // Exchange JWT for access token
        guard let tokenURL = URL(string: tokenURI) else { throw GoogleOCRError.invalidServiceAccount }
        var request = URLRequest(url: tokenURL)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        let bodyStr = "grant_type=urn:ietf:params:oauth:grant-type:jwt-bearer&assertion=\(jwt)"
        request.httpBody = bodyStr.data(using: .utf8)

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
                throw GoogleOCRError.invalidResponse
            }

            guard let tokenResp = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let accessToken = tokenResp["access_token"] as? String,
                  let expiresIn = tokenResp["expires_in"] as? Int else {
                throw GoogleOCRError.invalidResponse
            }

            cachedAccessToken = accessToken
            tokenExpiry = Date().addingTimeInterval(TimeInterval(expiresIn))
            return accessToken
        } catch {
            throw GoogleOCRError.networkError(error)
        }
    }

    private func signJWT(signingInput: String, privateKeyPEM: String) throws -> String? {
        // Strip PEM headers and base64 decode
        let lines = privateKeyPEM.components(separatedBy: "\n")
        let base64Lines = lines.filter { !$0.hasPrefix("-----") && !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        let base64 = base64Lines.joined()
        guard let keyData = Data(base64Encoded: base64) else { return nil }

        // Create SecKey from PKCS8 data
        let keyDict: [CFString: Any] = [
            kSecAttrKeyType: kSecAttrKeyTypeRSA,
            kSecAttrKeyClass: kSecAttrKeyClassPrivate,
            kSecAttrKeySizeInBits: NSNumber(value: keyData.count * 8),
            kSecReturnPersistentRef: true
        ]

        var error: Unmanaged<CFError>?
        guard let secKey = SecKeyCreateWithData(keyData as CFData, keyDict as CFDictionary, &error) else {
            // SecKeyCreateWithData may fail for some PEM encodings; return nil to fallback to API key path
            return nil
        }

        guard let algorithm = SecKeyAlgorithm.rsaSignatureMessagePKCS1v15SHA256 as SecKeyAlgorithm? else { return nil }
        guard SecKeyIsAlgorithmSupported(secKey, .sign, algorithm) else { return nil }

        guard let dataToSign = signingInput.data(using: .utf8) else { return nil }

        var signError: Unmanaged<CFError>?
        guard let signature = SecKeyCreateSignature(secKey, algorithm, dataToSign as CFData, &signError) as Data? else {
            return nil
        }

        // base64url encode
        var sigString = signature.base64EncodedString()
        sigString = sigString.replacingOccurrences(of: "+", with: "-")
        sigString = sigString.replacingOccurrences(of: "/", with: "_")
        sigString = sigString.replacingOccurrences(of: "=", with: "")
        return sigString
    }
}
