import Foundation

actor ProviderCoordinator {
    private let providers: [any ExitIPProvider]
    private var isFetching = false

    init(providers: [any ExitIPProvider]) {
        self.providers = providers
    }

    func fetchIdentity() async throws -> ExitIdentity {
        guard !isFetching else { throw ExitIPProviderError.checkAlreadyInProgress }
        isFetching = true
        defer { isFetching = false }

        for provider in providers {
            do {
                return try await provider.fetchIdentity()
            } catch is CancellationError {
                throw CancellationError()
            } catch {
                continue
            }
        }
        throw ExitIPProviderError.allProvidersFailed
    }
}
