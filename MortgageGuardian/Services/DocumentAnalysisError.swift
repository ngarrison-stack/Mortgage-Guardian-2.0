import Foundation

/// Comprehensive error types for document analysis operations
enum DocumentAnalysisError: Error, LocalizedError, Equatable {
    // Image processing errors
    case imageConversionFailed
    case imageDataCorrupted
    case imageFormatNotSupported
    case imageTooLarge(maxSizeBytes: Int)
    case imageTooSmall(minDimensions: CGSize)

    // Network and AWS errors
    case networkUnavailable
    case awsBackendUnavailable
    case awsAuthenticationFailed
    case awsQuotaExceeded
    case awsServiceError(code: Int, message: String)
    case requestTimeout
    case invalidAPIResponse

    // Document processing errors
    case noTextDetected
    case documentTypeNotSupported(type: String)
    case documentQualityTooLow(score: Double)
    case textExtractionFailed
    case mlModelUnavailable
    case processingInterrupted

    // Configuration errors
    case awsCredentialsNotConfigured
    case textractNotConfigured
    case invalidConfiguration(reason: String)

    // Data validation errors
    case invalidExtractedData
    case confidenceTooLow(score: Double, minimum: Double)
    case missingRequiredFields([String])
    case dataIntegrityCheckFailed

    // General errors
    case unknownError(underlying: Error)
    case operationCancelled
    case serviceUnavailable

    var errorDescription: String? {
        switch self {
        // Image processing errors
        case .imageConversionFailed:
            return "Failed to convert image to required format"
        case .imageDataCorrupted:
            return "Image data appears to be corrupted"
        case .imageFormatNotSupported:
            return "Image format is not supported for analysis"
        case .imageTooLarge(let maxSizeBytes):
            return "Image is too large. Maximum size: \(maxSizeBytes / 1024 / 1024)MB"
        case .imageTooSmall(let minDimensions):
            return "Image is too small. Minimum dimensions: \(Int(minDimensions.width))x\(Int(minDimensions.height))"

        // Network and AWS errors
        case .networkUnavailable:
            return "Network connection is unavailable"
        case .awsBackendUnavailable:
            return "AWS backend service is currently unavailable"
        case .awsAuthenticationFailed:
            return "AWS authentication failed. Please check your credentials"
        case .awsQuotaExceeded:
            return "AWS service quota exceeded. Please try again later"
        case .awsServiceError(let code, let message):
            return "AWS service error (\(code)): \(message)"
        case .requestTimeout:
            return "Request timed out. Please try again"
        case .invalidAPIResponse:
            return "Received invalid response from server"

        // Document processing errors
        case .noTextDetected:
            return "No text could be detected in the document"
        case .documentTypeNotSupported(let type):
            return "Document type '\(type)' is not supported"
        case .documentQualityTooLow(let score):
            return "Document quality is too low for analysis (score: \(String(format: "%.2f", score)))"
        case .textExtractionFailed:
            return "Failed to extract text from the document"
        case .mlModelUnavailable:
            return "Machine learning model is unavailable"
        case .processingInterrupted:
            return "Document processing was interrupted"

        // Configuration errors
        case .awsCredentialsNotConfigured:
            return "AWS credentials are not configured. Please set up your credentials in Settings"
        case .textractNotConfigured:
            return "AWS Textract is not configured. Please complete the setup in Settings"
        case .invalidConfiguration(let reason):
            return "Invalid configuration: \(reason)"

        // Data validation errors
        case .invalidExtractedData:
            return "Extracted data is invalid or incomplete"
        case .confidenceTooLow(let score, let minimum):
            return "Analysis confidence too low (\(String(format: "%.2f", score * 100))%). Minimum required: \(String(format: "%.2f", minimum * 100))%"
        case .missingRequiredFields(let fields):
            return "Missing required fields: \(fields.joined(separator: ", "))"
        case .dataIntegrityCheckFailed:
            return "Data integrity check failed"

        // General errors
        case .unknownError(let underlying):
            return "An unexpected error occurred: \(underlying.localizedDescription)"
        case .operationCancelled:
            return "Operation was cancelled by user"
        case .serviceUnavailable:
            return "Service is temporarily unavailable"
        }
    }

    var failureReason: String? {
        switch self {
        case .imageConversionFailed:
            return "The image could not be converted to the required JPEG format for processing"
        case .networkUnavailable:
            return "No internet connection is available to reach the AWS backend services"
        case .awsBackendUnavailable:
            return "The AWS backend service is experiencing issues or is under maintenance"
        case .awsAuthenticationFailed:
            return "The provided AWS credentials are invalid or have expired"
        case .noTextDetected:
            return "The document image may be too blurry, skewed, or contain no readable text"
        case .documentQualityTooLow:
            return "The document image quality is insufficient for accurate text extraction"
        case .awsCredentialsNotConfigured:
            return "AWS credentials have not been set up in the application settings"
        case .confidenceTooLow:
            return "The analysis confidence is below the acceptable threshold for reliable results"
        default:
            return nil
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .imageConversionFailed, .imageDataCorrupted:
            return "Try taking a new photo or selecting a different image"
        case .imageTooLarge:
            return "Try reducing the image size or taking a photo with lower resolution"
        case .imageTooSmall:
            return "Take a closer photo or use a higher resolution image"
        case .networkUnavailable:
            return "Check your internet connection and try again"
        case .awsBackendUnavailable, .serviceUnavailable:
            return "Please try again in a few minutes. If the problem persists, contact support"
        case .awsAuthenticationFailed:
            return "Go to Settings and update your AWS credentials"
        case .awsQuotaExceeded:
            return "Wait for your AWS quota to reset or upgrade your AWS plan"
        case .noTextDetected:
            return "Take a clearer photo with better lighting and ensure the document is fully visible"
        case .documentQualityTooLow:
            return "Take a new photo with better lighting, reduce glare, and ensure the document is flat"
        case .awsCredentialsNotConfigured, .textractNotConfigured:
            return "Go to Settings > AWS Configuration to set up your credentials"
        case .confidenceTooLow:
            return "Try taking a clearer photo or manually verify the extracted information"
        case .missingRequiredFields:
            return "Ensure all required information is visible in the document image"
        case .operationCancelled:
            return "Start the analysis again if needed"
        default:
            return "Please try again or contact support if the issue persists"
        }
    }

    var isRetryable: Bool {
        switch self {
        case .networkUnavailable, .awsBackendUnavailable, .requestTimeout,
             .awsQuotaExceeded, .serviceUnavailable, .processingInterrupted:
            return true
        case .imageConversionFailed, .imageDataCorrupted, .noTextDetected,
             .documentQualityTooLow, .textExtractionFailed:
            return true // User can retry with different image
        case .awsAuthenticationFailed, .awsCredentialsNotConfigured,
             .textractNotConfigured, .documentTypeNotSupported:
            return false // Requires configuration changes
        default:
            return false
        }
    }

    var requiresUserAction: Bool {
        switch self {
        case .awsCredentialsNotConfigured, .textractNotConfigured,
             .awsAuthenticationFailed, .invalidConfiguration:
            return true
        case .imageConversionFailed, .imageDataCorrupted, .imageTooLarge,
             .imageTooSmall, .noTextDetected, .documentQualityTooLow:
            return true
        default:
            return false
        }
    }

    /// Convert from various error types to DocumentAnalysisError
    static func from(_ error: Error) -> DocumentAnalysisError {
        if let analysisError = error as? DocumentAnalysisError {
            return analysisError
        }

        if let backendError = error as? AWSBackendClient.BackendError {
            switch backendError {
            case .networkError:
                return .networkUnavailable
            case .authenticationRequired:
                return .awsAuthenticationFailed
            case .serverError(let code, let message):
                return .awsServiceError(code: code, message: message)
            case .invalidResponse, .noData:
                return .invalidAPIResponse
            case .encodingError, .decodingError:
                return .invalidAPIResponse
            case .invalidURL:
                return .invalidConfiguration(reason: "Invalid API URL")
            }
        }

        if let textractError = error as? AWSTextractService.TextractError {
            switch textractError {
            case .missingCredentials:
                return .awsCredentialsNotConfigured
            case .invalidAWSCredentials:
                return .awsAuthenticationFailed
            case .networkError:
                return .networkUnavailable
            case .invalidResponse:
                return .invalidAPIResponse
            case .encodingFailed:
                return .imageConversionFailed
            case .signatureError:
                return .awsAuthenticationFailed
            }
        }

        // Handle common Foundation errors
        if let nsError = error as NSError? {
            switch nsError.domain {
            case NSURLErrorDomain:
                switch nsError.code {
                case NSURLErrorNotConnectedToInternet, NSURLErrorNetworkConnectionLost:
                    return .networkUnavailable
                case NSURLErrorTimedOut:
                    return .requestTimeout
                case NSURLErrorCancelled:
                    return .operationCancelled
                default:
                    return .networkUnavailable
                }
            default:
                break
            }
        }

        return .unknownError(underlying: error)
    }
}

// MARK: - Error Recovery Helpers

extension DocumentAnalysisError {
    /// Suggest fallback processing when cloud processing fails
    var shouldFallbackToLocal: Bool {
        switch self {
        case .networkUnavailable, .awsBackendUnavailable, .awsServiceError,
             .requestTimeout, .awsQuotaExceeded, .invalidAPIResponse:
            return true
        case .awsAuthenticationFailed, .awsCredentialsNotConfigured:
            return false // These require user configuration
        default:
            return false
        }
    }

    /// Determine if error should trigger immediate retry
    var shouldRetryImmediately: Bool {
        switch self {
        case .requestTimeout, .networkUnavailable:
            return true
        default:
            return false
        }
    }

    /// Get retry delay in seconds
    var retryDelay: TimeInterval {
        switch self {
        case .networkUnavailable:
            return 2.0
        case .awsBackendUnavailable, .serviceUnavailable:
            return 5.0
        case .requestTimeout:
            return 1.0
        case .awsQuotaExceeded:
            return 60.0
        default:
            return 0.0
        }
    }
}

// MARK: - User-Friendly Error Messages

extension DocumentAnalysisError {
    /// Get a simplified, user-friendly error message
    var userFriendlyMessage: String {
        switch self {
        case .imageConversionFailed, .imageDataCorrupted, .imageFormatNotSupported:
            return "There's an issue with the image. Please try taking a new photo."
        case .imageTooLarge:
            return "The image is too large. Please try a smaller image or lower resolution."
        case .imageTooSmall:
            return "The image is too small. Please take a closer photo."
        case .networkUnavailable:
            return "No internet connection. Please check your connection and try again."
        case .awsBackendUnavailable, .serviceUnavailable:
            return "The service is temporarily unavailable. Please try again in a few minutes."
        case .awsAuthenticationFailed, .awsCredentialsNotConfigured:
            return "Please set up your AWS credentials in Settings."
        case .noTextDetected:
            return "No text found in the image. Please ensure the document is clearly visible."
        case .documentQualityTooLow:
            return "The document image quality is too low. Please take a clearer photo."
        case .confidenceTooLow:
            return "The analysis confidence is low. Please verify the results or take a clearer photo."
        default:
            return "An error occurred during analysis. Please try again."
        }
    }

    /// Get appropriate icon for the error type
    var iconName: String {
        switch self {
        case .imageConversionFailed, .imageDataCorrupted, .imageFormatNotSupported,
             .imageTooLarge, .imageTooSmall, .noTextDetected, .documentQualityTooLow:
            return "camera.fill"
        case .networkUnavailable, .awsBackendUnavailable, .serviceUnavailable:
            return "wifi.slash"
        case .awsAuthenticationFailed, .awsCredentialsNotConfigured:
            return "key.fill"
        case .operationCancelled:
            return "xmark.circle.fill"
        default:
            return "exclamationmark.triangle.fill"
        }
    }
}