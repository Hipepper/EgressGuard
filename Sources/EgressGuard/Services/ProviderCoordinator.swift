import Foundation

actor ProviderCoordinator {
    private let providers: [any ExitIPProvider]
    private let maximumAttempts: Int
    private var isFetching = false

    init(providers: [any ExitIPProvider], maximumAttempts: Int = 3) {
        self.providers = providers
        self.maximumAttempts = max(1, maximumAttempts)
    }

    func fetchIdentity() async throws -> ExitIdentity {
        guard !isFetching else { throw ExitIPProviderError.checkAlreadyInProgress }
        isFetching = true
        defer { isFetching = false }

        for _ in 0..<maximumAttempts {
            for provider in providers {
                do {
                    return try await provider.fetchIdentity()
                } catch is CancellationError {
                    throw CancellationError()
                } catch {
                    continue
                }
            }
        }
        throw ExitIPProviderError.allProvidersFailed
    }
}
