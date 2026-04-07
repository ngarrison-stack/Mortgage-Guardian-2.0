// APIConfiguration.swift
import Foundation

enum APIEnvironment {
    case development
    case staging
    case production

    var baseURL: String {
        switch self {
        case .development:
            return "http://localhost:3000"
        case .staging:
            return "https://staging-api.mortgageguardian.com"
        case .production:
            return "https://api.mortgageguardian.com"
        }
    }
}

struct APIConfiguration {
    static var current: APIEnvironment = {
        #if DEBUG
        return .development
        #else
        return .production
        #endif
    }()

    static var baseURL: String {
        current.baseURL
    }
}
