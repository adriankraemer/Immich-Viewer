import Testing
import Foundation
@testable import Immich_Viewer

@Suite("NetworkService Tests")
struct NetworkServiceTests {
    
    @Test("NetworkService should initialize with empty credentials")
    func testInitialization() {
        let userManager = UserManager(storage: MockUserStorage())
        let networkService = NetworkService(userManager: userManager)
        
        #expect(networkService.baseURL.isEmpty)
        #expect(networkService.accessToken == nil)
        #expect(networkService.currentAuthType == .jwt)
    }
    
    @Test("NetworkService should clear credentials")
    func testClearCredentials() async throws {
        let userManager = UserManager(storage: MockUserStorage())
        let networkService = NetworkService(userManager: userManager)
        
        networkService.baseURL = "https://example.com"
        networkService.accessToken = "token-123"
        networkService.currentAuthType = .apiKey
        
        networkService.clearCredentials()
        
        // Wait for async operation to complete
        try await Task.sleep(nanoseconds: 100_000_000)
        
        await MainActor.run {
            #expect(networkService.baseURL.isEmpty)
            #expect(networkService.accessToken == nil)
            #expect(networkService.currentAuthType == .jwt)
        }
    }
    
    @Test("NetworkService should update credentials from current user")
    func testUpdateCredentialsFromCurrentUser() async throws {
        let storage = MockUserStorage()
        let userManager = UserManager(storage: storage)
        
        let testUser = SavedUser(
            id: "test-user-1",
            email: "test@example.com",
            name: "Test User",
            serverURL: "https://example.com",
            authType: .jwt
        )
        
        try await userManager.saveUser(testUser, token: "test-token-123")
        await MainActor.run {
            userManager.currentUser = testUser
        }
        
        let networkService = NetworkService(userManager: userManager)
        networkService.updateCredentialsFromCurrentUser()
        
        // Wait a bit for async updates
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        
        await MainActor.run {
            #expect(networkService.baseURL == "https://example.com")
            #expect(networkService.accessToken == "test-token-123")
            #expect(networkService.currentAuthType == .jwt)
        }
    }
    
    @Test("ImmichError shouldLogout should return correct values")
    func testImmichErrorShouldLogout() {
        #expect(ImmichError.notAuthenticated.shouldLogout == true)
        #expect(ImmichError.forbidden.shouldLogout == true)
        #expect(ImmichError.serverError(500).shouldLogout == false)
        #expect(ImmichError.networkError.shouldLogout == false)
        #expect(ImmichError.clientError(404).shouldLogout == false)
        #expect(ImmichError.invalidURL.shouldLogout == false)
    }
    
    @Test("ImmichError should have correct error descriptions")
    func testImmichErrorDescriptions() {
        #expect(ImmichError.notAuthenticated.errorDescription?.contains("authenticated") == true)
        #expect(ImmichError.forbidden.errorDescription?.contains("forbidden") == true)
        #expect(ImmichError.invalidURL.errorDescription?.contains("Invalid URL") == true)
        #expect(ImmichError.networkError.errorDescription?.contains("Network") == true)
        
        if case .serverError(let code) = ImmichError.serverError(500) {
            #expect(code == 500)
        }
        
        if case .clientError(let code) = ImmichError.clientError(404) {
            #expect(code == 404)
        }
    }
}

