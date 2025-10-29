import Foundation
import Combine
import os.log

/// Comprehensive error handling system for Mortgage Guardian app
/// Provides standardized error types, user-friendly messages, and recovery suggestions

// MARK: - Core Error Protocol

/// Base protocol for all app errors
public protocol AppError: LocalizedError {
    var errorCode: String { get }
    var severity: ErrorSeverity { get }
    var userMessage: String { get }
    var recoveryOptions: [RecoveryOption] { get }
    var analyticsData: [String: Any] { get }
    var underlyingError: Error? { get }
}

// MARK: - Error Severity

public enum ErrorSeverity: String, CaseIterable {
    case info = "info"
    case warning = "warning"
    case error = "error"
    case critical = "critical"

    var logLevel: OSLogType {
        switch self {
        case .info: return .info
        case .warning: return .default
        case .error: return .error
        case .critical: return .fault
        }
    }

    var shouldShowAlert: Bool {
        switch self {
        case .info, .warning: return false
        case .error, .critical: return true
        }
    }
}

// MARK: - Recovery Options

public struct RecoveryOption {
    let title: String
    let action: () async -> Void
    let isDestructive: Bool
    let isPreferred: Bool

    public init(title: String, isDestructive: Bool = false, isPreferred: Bool = false, action: @escaping () async -> Void) {
        self.title = title
        self.isDestructive = isDestructive
        self.isPreferred = isPreferred
        self.action = action
    }
}

// MARK: - Network Errors

public enum NetworkError: AppError {
    case noConnection
    case timeout
    case serverError(statusCode: Int, message: String?)
    case rateLimited(retryAfter: TimeInterval?)
    case invalidResponse
    case unauthorized
    case forbidden
    case notFound
    case tooManyRequests
    case serverMaintenance
    case certificateError

    public var errorCode: String {
        switch self {
        case .noConnection: return "NET_001"
        case .timeout: return "NET_002"
        case .serverError: return "NET_003"
        case .rateLimited: return "NET_004"
        case .invalidResponse: return "NET_005"
        case .unauthorized: return "NET_006"
        case .forbidden: return "NET_007"
        case .notFound: return "NET_008"
        case .tooManyRequests: return "NET_009"
        case .serverMaintenance: return "NET_010"
        case .certificateError: return "NET_011"
        }
    }

    public var severity: ErrorSeverity {
        switch self {
        case .noConnection, .timeout: return .warning
        case .serverError, .invalidResponse: return .error
        case .rateLimited, .tooManyRequests: return .warning
        case .unauthorized, .forbidden: return .error
        case .notFound: return .info
        case .serverMaintenance: return .warning
        case .certificateError: return .critical
        }
    }

    public var userMessage: String {
        switch self {
        case .noConnection:
            return "No internet connection. Please check your network settings."
        case .timeout:
            return "Request timed out. Please try again."
        case .serverError(_, let message):
            return message ?? "Server error occurred. Please try again later."
        case .rateLimited(let retryAfter):
            let waitTime = retryAfter.map { "\(Int($0)) seconds" } ?? "a moment"
            return "Too many requests. Please wait \(waitTime) and try again."
        case .invalidResponse:
            return "Invalid response from server. Please try again."
        case .unauthorized:
            return "Authentication required. Please log in again."
        case .forbidden:
            return "Access denied. You don't have permission for this action."
        case .notFound:
            return "The requested resource was not found."
        case .tooManyRequests:
            return "Too many requests. Please slow down and try again."
        case .serverMaintenance:
            return "Service is temporarily unavailable due to maintenance."
        case .certificateError:
            return "Security certificate error. Please check your connection."
        }
    }

    public var recoveryOptions: [RecoveryOption] {
        switch self {
        case .noConnection:
            return [
                RecoveryOption(title: "Check Network Settings", isPreferred: true) {
                    await UIApplication.shared.open(URL(string: UIApplication.openSettingsURLString)!)
                },
                RecoveryOption(title: "Try Again") { /* Retry action */ }
            ]
        case .timeout:
            return [
                RecoveryOption(title: "Try Again", isPreferred: true) { /* Retry action */ },
                RecoveryOption(title: "Check Connection") { /* Network check */ }
            ]
        case .unauthorized:
            return [
                RecoveryOption(title: "Log In", isPreferred: true) { /* Navigate to login */ },
                RecoveryOption(title: "Cancel") { /* Cancel action */ }
            ]
        default:
            return [
                RecoveryOption(title: "Try Again", isPreferred: true) { /* Retry action */ },
                RecoveryOption(title: "Cancel") { /* Cancel action */ }
            ]
        }
    }

    public var analyticsData: [String: Any] {
        var data: [String: Any] = ["error_code": errorCode, "severity": severity.rawValue]
        switch self {
        case .serverError(let statusCode, _):
            data["status_code"] = statusCode
        case .rateLimited(let retryAfter):
            data["retry_after"] = retryAfter ?? 0
        default:
            break
        }
        return data
    }

    public var underlyingError: Error? { nil }

    public var errorDescription: String? { userMessage }
}

// MARK: - Data Processing Errors

public enum DataProcessingError: AppError {
    case invalidInput(field: String)
    case missingRequiredData(field: String)
    case validationFailed(reason: String)
    case parsingError(Error)
    case corruptedData
    case incompatibleFormat
    case dataTooLarge(size: Int, limit: Int)
    case processingTimeout
    case insufficientMemory

    public var errorCode: String {
        switch self {
        case .invalidInput: return "DATA_001"
        case .missingRequiredData: return "DATA_002"
        case .validationFailed: return "DATA_003"
        case .parsingError: return "DATA_004"
        case .corruptedData: return "DATA_005"
        case .incompatibleFormat: return "DATA_006"
        case .dataTooLarge: return "DATA_007"
        case .processingTimeout: return "DATA_008"
        case .insufficientMemory: return "DATA_009"
        }
    }

    public var severity: ErrorSeverity {
        switch self {
        case .invalidInput, .missingRequiredData, .validationFailed: return .warning
        case .parsingError, .incompatibleFormat: return .error
        case .corruptedData, .insufficientMemory: return .critical
        case .dataTooLarge, .processingTimeout: return .error
        }
    }

    public var userMessage: String {
        switch self {
        case .invalidInput(let field):
            return "Invalid input for \(field). Please check and try again."
        case .missingRequiredData(let field):
            return "Required field '\(field)' is missing. Please provide this information."
        case .validationFailed(let reason):
            return "Validation failed: \(reason)"
        case .parsingError:
            return "Failed to process the data. Please check the format and try again."
        case .corruptedData:
            return "The data appears to be corrupted. Please try uploading again."
        case .incompatibleFormat:
            return "File format not supported. Please use a supported format."
        case .dataTooLarge(_, let limit):
            return "File is too large. Maximum size is \(ByteCountFormatter().string(fromByteCount: Int64(limit)))."
        case .processingTimeout:
            return "Processing took too long and was cancelled. Please try again."
        case .insufficientMemory:
            return "Not enough memory to process this data. Please try with a smaller file."
        }
    }

    public var recoveryOptions: [RecoveryOption] {
        switch self {
        case .invalidInput, .missingRequiredData, .validationFailed:
            return [
                RecoveryOption(title: "Edit Input", isPreferred: true) { /* Navigate back to input */ },
                RecoveryOption(title: "Cancel") { /* Cancel operation */ }
            ]
        case .corruptedData, .incompatibleFormat:
            return [
                RecoveryOption(title: "Try Different File", isPreferred: true) { /* File picker */ },
                RecoveryOption(title: "Cancel") { /* Cancel operation */ }
            ]
        case .dataTooLarge:
            return [
                RecoveryOption(title: "Choose Smaller File", isPreferred: true) { /* File picker */ },
                RecoveryOption(title: "Compress File") { /* Compression options */ },
                RecoveryOption(title: "Cancel") { /* Cancel operation */ }
            ]
        default:
            return [
                RecoveryOption(title: "Try Again", isPreferred: true) { /* Retry operation */ },
                RecoveryOption(title: "Cancel") { /* Cancel operation */ }
            ]
        }
    }

    public var analyticsData: [String: Any] {
        var data: [String: Any] = ["error_code": errorCode, "severity": severity.rawValue]
        switch self {
        case .invalidInput(let field), .missingRequiredData(let field):
            data["field"] = field
        case .dataTooLarge(let size, let limit):
            data["size"] = size
            data["limit"] = limit
        default:
            break
        }
        return data
    }

    public var underlyingError: Error? {
        switch self {
        case .parsingError(let error): return error
        default: return nil
        }
    }

    public var errorDescription: String? { userMessage }
}

// MARK: - Security Errors

public enum SecurityError: AppError {
    case authenticationFailed
    case authorizationDenied
    case tokenExpired
    case invalidCredentials
    case biometricAuthUnavailable
    case biometricAuthFailed
    case keyChainError(Error)
    case encryptionFailed
    case decryptionFailed
    case integrityCheckFailed
    case suspiciousActivity
    case deviceNotTrusted

    public var errorCode: String {
        switch self {
        case .authenticationFailed: return "SEC_001"
        case .authorizationDenied: return "SEC_002"
        case .tokenExpired: return "SEC_003"
        case .invalidCredentials: return "SEC_004"
        case .biometricAuthUnavailable: return "SEC_005"
        case .biometricAuthFailed: return "SEC_006"
        case .keyChainError: return "SEC_007"
        case .encryptionFailed: return "SEC_008"
        case .decryptionFailed: return "SEC_009"
        case .integrityCheckFailed: return "SEC_010"
        case .suspiciousActivity: return "SEC_011"
        case .deviceNotTrusted: return "SEC_012"
        }
    }

    public var severity: ErrorSeverity {
        switch self {
        case .authenticationFailed, .authorizationDenied, .invalidCredentials: return .warning
        case .tokenExpired, .biometricAuthUnavailable, .biometricAuthFailed: return .info
        case .keyChainError, .encryptionFailed, .decryptionFailed: return .error
        case .integrityCheckFailed, .suspiciousActivity, .deviceNotTrusted: return .critical
        }
    }

    public var userMessage: String {
        switch self {
        case .authenticationFailed:
            return "Authentication failed. Please check your credentials."
        case .authorizationDenied:
            return "Access denied. You don't have permission for this action."
        case .tokenExpired:
            return "Your session has expired. Please log in again."
        case .invalidCredentials:
            return "Invalid username or password. Please try again."
        case .biometricAuthUnavailable:
            return "Biometric authentication is not available on this device."
        case .biometricAuthFailed:
            return "Biometric authentication failed. Please try again or use your passcode."
        case .keyChainError:
            return "Failed to access secure storage. Please try again."
        case .encryptionFailed:
            return "Failed to encrypt data. Please try again."
        case .decryptionFailed:
            return "Failed to decrypt data. This may indicate data corruption."
        case .integrityCheckFailed:
            return "Data integrity check failed. The data may have been tampered with."
        case .suspiciousActivity:
            return "Suspicious activity detected. For security, this action has been blocked."
        case .deviceNotTrusted:
            return "This device is not trusted. Please verify your identity."
        }
    }

    public var recoveryOptions: [RecoveryOption] {
        switch self {
        case .authenticationFailed, .invalidCredentials:
            return [
                RecoveryOption(title: "Try Again", isPreferred: true) { /* Retry auth */ },
                RecoveryOption(title: "Reset Password") { /* Password reset */ },
                RecoveryOption(title: "Contact Support") { /* Support contact */ }
            ]
        case .tokenExpired:
            return [
                RecoveryOption(title: "Log In Again", isPreferred: true) { /* Navigate to login */ }
            ]
        case .biometricAuthFailed:
            return [
                RecoveryOption(title: "Try Again", isPreferred: true) { /* Retry biometric */ },
                RecoveryOption(title: "Use Passcode") { /* Fallback to passcode */ }
            ]
        case .suspiciousActivity, .deviceNotTrusted:
            return [
                RecoveryOption(title: "Verify Identity") { /* Identity verification */ },
                RecoveryOption(title: "Contact Support") { /* Support contact */ }
            ]
        default:
            return [
                RecoveryOption(title: "Try Again", isPreferred: true) { /* Retry operation */ },
                RecoveryOption(title: "Contact Support") { /* Support contact */ }
            ]
        }
    }

    public var analyticsData: [String: Any] {
        return ["error_code": errorCode, "severity": severity.rawValue]
    }

    public var underlyingError: Error? {
        switch self {
        case .keyChainError(let error): return error
        default: return nil
        }
    }

    public var errorDescription: String? { userMessage }
}

// MARK: - Business Logic Errors

public enum BusinessLogicError: AppError {
    case invalidBusinessRule(rule: String)
    case calculationError(operation: String)
    case dataInconsistency(description: String)
    case workflowViolation(step: String)
    case preconditionNotMet(condition: String)
    case postconditionFailed(condition: String)
    case stateTransitionInvalid(from: String, to: String)
    case resourceUnavailable(resource: String)
    case quotaExceeded(limit: String)
    case operationNotAllowed(reason: String)

    public var errorCode: String {
        switch self {
        case .invalidBusinessRule: return "BIZ_001"
        case .calculationError: return "BIZ_002"
        case .dataInconsistency: return "BIZ_003"
        case .workflowViolation: return "BIZ_004"
        case .preconditionNotMet: return "BIZ_005"
        case .postconditionFailed: return "BIZ_006"
        case .stateTransitionInvalid: return "BIZ_007"
        case .resourceUnavailable: return "BIZ_008"
        case .quotaExceeded: return "BIZ_009"
        case .operationNotAllowed: return "BIZ_010"
        }
    }

    public var severity: ErrorSeverity {
        switch self {
        case .invalidBusinessRule, .workflowViolation, .operationNotAllowed: return .warning
        case .calculationError, .dataInconsistency: return .error
        case .preconditionNotMet, .postconditionFailed: return .error
        case .stateTransitionInvalid: return .warning
        case .resourceUnavailable, .quotaExceeded: return .warning
        }
    }

    public var userMessage: String {
        switch self {
        case .invalidBusinessRule(let rule):
            return "Business rule violation: \(rule)"
        case .calculationError(let operation):
            return "Calculation error in \(operation). Please try again."
        case .dataInconsistency(let description):
            return "Data inconsistency detected: \(description)"
        case .workflowViolation(let step):
            return "Workflow violation at step: \(step). Please follow the correct sequence."
        case .preconditionNotMet(let condition):
            return "Precondition not met: \(condition)"
        case .postconditionFailed(let condition):
            return "Postcondition failed: \(condition)"
        case .stateTransitionInvalid(let from, let to):
            return "Invalid state transition from \(from) to \(to)"
        case .resourceUnavailable(let resource):
            return "\(resource) is currently unavailable. Please try again later."
        case .quotaExceeded(let limit):
            return "Quota exceeded: \(limit). Please wait or upgrade your plan."
        case .operationNotAllowed(let reason):
            return "Operation not allowed: \(reason)"
        }
    }

    public var recoveryOptions: [RecoveryOption] {
        switch self {
        case .invalidBusinessRule, .workflowViolation:
            return [
                RecoveryOption(title: "Review Requirements") { /* Show help */ },
                RecoveryOption(title: "Cancel") { /* Cancel operation */ }
            ]
        case .calculationError:
            return [
                RecoveryOption(title: "Try Again", isPreferred: true) { /* Retry calculation */ },
                RecoveryOption(title: "Review Input") { /* Go back to input */ }
            ]
        case .quotaExceeded:
            return [
                RecoveryOption(title: "Upgrade Plan") { /* Navigate to upgrade */ },
                RecoveryOption(title: "Try Later") { /* Schedule retry */ }
            ]
        default:
            return [
                RecoveryOption(title: "Try Again", isPreferred: true) { /* Retry operation */ },
                RecoveryOption(title: "Cancel") { /* Cancel operation */ }
            ]
        }
    }

    public var analyticsData: [String: Any] {
        var data: [String: Any] = ["error_code": errorCode, "severity": severity.rawValue]
        switch self {
        case .invalidBusinessRule(let rule):
            data["rule"] = rule
        case .calculationError(let operation):
            data["operation"] = operation
        case .stateTransitionInvalid(let from, let to):
            data["from_state"] = from
            data["to_state"] = to
        default:
            break
        }
        return data
    }

    public var underlyingError: Error? { nil }

    public var errorDescription: String? { userMessage }
}

// MARK: - Error Handler

/// Centralized error handling service
@MainActor
public final class ErrorHandler: ObservableObject {
    public static let shared = ErrorHandler()

    @Published public var currentError: AppError?
    @Published public var errorHistory: [ErrorLogEntry] = []

    private let logger = Logger(subsystem: "com.mortgageguardian", category: "ErrorHandler")
    private let maxHistorySize = 100

    public struct ErrorLogEntry {
        let error: AppError
        let timestamp: Date
        let context: String?
        let handled: Bool
    }

    private init() {}

    /// Handle an error with optional context
    public func handle(_ error: Error, context: String? = nil, showAlert: Bool = true) {
        let appError: AppError

        if let error = error as? AppError {
            appError = error
        } else {
            appError = mapToAppError(error)
        }

        // Log the error
        logError(appError, context: context)

        // Add to history
        addToHistory(appError, context: context, handled: showAlert)

        // Show to user if appropriate
        if showAlert && appError.severity.shouldShowAlert {
            currentError = appError
        }

        // Send analytics
        sendAnalytics(appError, context: context)
    }

    /// Clear current error
    public func clearCurrentError() {
        currentError = nil
    }

    /// Get retry mechanism with exponential backoff
    public func retryWithBackoff<T>(
        operation: @escaping () async throws -> T,
        maxRetries: Int = 3,
        baseDelay: TimeInterval = 1.0,
        maxDelay: TimeInterval = 60.0
    ) async throws -> T {
        var lastError: Error?

        for attempt in 0..<maxRetries {
            do {
                return try await operation()
            } catch {
                lastError = error

                if attempt == maxRetries - 1 {
                    break
                }

                let delay = min(baseDelay * pow(2.0, Double(attempt)), maxDelay)
                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            }
        }

        throw lastError ?? NetworkError.timeout
    }

    // MARK: - Private Methods

    private func mapToAppError(_ error: Error) -> AppError {
        switch error {
        case let urlError as URLError:
            return mapURLError(urlError)
        case let nsError as NSError:
            return mapNSError(nsError)
        default:
            return DataProcessingError.parsingError(error)
        }
    }

    private func mapURLError(_ error: URLError) -> NetworkError {
        switch error.code {
        case .notConnectedToInternet, .networkConnectionLost:
            return .noConnection
        case .timedOut:
            return .timeout
        case .userAuthenticationRequired:
            return .unauthorized
        case .cannotFindHost, .dnsLookupFailed:
            return .notFound
        case .secureConnectionFailed, .serverCertificateUntrusted:
            return .certificateError
        default:
            return .serverError(statusCode: error.errorCode, message: error.localizedDescription)
        }
    }

    private func mapNSError(_ error: NSError) -> AppError {
        switch error.domain {
        case NSURLErrorDomain:
            return mapURLError(URLError(URLError.Code(rawValue: error.code)!))
        default:
            return DataProcessingError.parsingError(error)
        }
    }

    private func logError(_ error: AppError, context: String?) {
        let message = "Error: \(error.errorCode) - \(error.userMessage)"
        let contextInfo = context.map { " Context: \($0)" } ?? ""

        logger.log(level: error.severity.logLevel, "\(message)\(contextInfo)")

        if let underlyingError = error.underlyingError {
            logger.error("Underlying error: \(underlyingError.localizedDescription)")
        }
    }

    private func addToHistory(_ error: AppError, context: String?, handled: Bool) {
        let entry = ErrorLogEntry(
            error: error,
            timestamp: Date(),
            context: context,
            handled: handled
        )

        errorHistory.append(entry)

        // Maintain history size limit
        if errorHistory.count > maxHistorySize {
            errorHistory.removeFirst(errorHistory.count - maxHistorySize)
        }
    }

    private func sendAnalytics(_ error: AppError, context: String?) {
        var analyticsData = error.analyticsData
        if let context = context {
            analyticsData["context"] = context
        }
        analyticsData["timestamp"] = Date().timeIntervalSince1970

        // In a real app, this would send to your analytics service
        logger.info("Analytics: \(analyticsData)")
    }
}

// MARK: - Result Extensions

extension Result where Failure == Error {
    /// Handle the result with the error handler
    @MainActor
    public func handleError(context: String? = nil) -> Success? {
        switch self {
        case .success(let value):
            return value
        case .failure(let error):
            ErrorHandler.shared.handle(error, context: context)
            return nil
        }
    }
}

// MARK: - Async Extensions

extension Task where Failure == Error {
    /// Create a task with automatic error handling
    @MainActor
    public static func withErrorHandling(
        context: String? = nil,
        priority: TaskPriority? = nil,
        operation: @escaping @Sendable () async throws -> Success
    ) -> Task<Success?, Never> {
        Task(priority: priority) {
            do {
                return try await operation()
            } catch {
                await ErrorHandler.shared.handle(error, context: context)
                return nil
            }
        }
    }
}