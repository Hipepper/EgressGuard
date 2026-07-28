import Foundation

protocol ExitIPProvider: Sendable {
    var id: String { get }
    func fetchIdentity() async throws -> ExitIdentity
}

enum ExitIPProviderError: Error, Equatable, Sendable {
    case invalidResponse
    case httpStatus(Int)
    case serviceRejected(String)
    case malformedPayload
    case invalidIPAddress(String)
    case invalidCountryCode(String)
    case allProvidersFailed
    case checkAlreadyInProgress
}

extension ExitIPProviderError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .invalidResponse: "服务返回了无效响应"
        case let .httpStatus(status): "服务返回 HTTP \(status)"
        case let .serviceRejected(message): "服务拒绝请求：\(message)"
        case .malformedPayload: "服务数据格式无效"
        case let .invalidIPAddress(ip): "服务返回了无效 IP：\(ip)"
        case let .invalidCountryCode(code): "服务返回了无效国家代码：\(code)"
        case .allProvidersFailed: "所有出口检测服务均不可用"
        case .checkAlreadyInProgress: "已有检测正在进行"
        }
    }
}
