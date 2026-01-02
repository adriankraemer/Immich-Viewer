import Testing
import Foundation
@testable import Immich_AppleTV

@Suite("AuthenticationService Tests")
struct AuthenticationServiceTests {
    
    @Test("AuthenticationService should initialize with unauthenticated state")
    func testInitialization() async {
        let userManager = UserManager(storage: MockUserStorage())
        let networkService = NetworkService(userManager: userManager)
        
        let authService = await MainActor.run {
            AuthenticationService(networkService: networkService, userManager: userManager)
        }
        
        await MainActor.run {
            #expect(authService.isAuthenticated == false)
            #expect(authService.currentUser == nil)
        }
    }
    
    @Test("AuthenticationService should get auth headers for JWT")
    func testGetAuthHeadersJWT() async throws {
        let storage = MockUserStorage()
        let userManager = UserManager(storage: storage)
        let networkService = NetworkService(userManager: userManager)
        
        let authService = await MainActor.run {
            AuthenticationService(networkService: networkService, userManager: userManager)
        }
        
        let testUser = SavedUser(
            id: "test-user-1",
            email: "test@example.com",
            name: "Test User",
            serverURL: "https://example.com",
            authType: .jwt
        )
        
        await MainActor.run {
            networkService.baseURL = "https://example.com"
            networkService.accessToken = "jwt-token-123"
            userManager.currentUser = testUser
        }
        
        // Wait for async update
        try await Task.sleep(nanoseconds: 100_000_000)
        
        let headers = await MainActor.run {
            authService.getAuthHeaders()
        }
        #expect(headers["Authorization"] == "Bearer jwt-token-123")
        #expect(headers["x-api-key"] == nil)
    }
    
    @Test("AuthenticationService should get auth headers for API key")
    func testGetAuthHeadersAPIKey() async throws {
        let storage = MockUserStorage()
        let userManager = UserManager(storage: storage)
        let networkService = NetworkService(userManager: userManager)
        
        let authService = await MainActor.run {
            AuthenticationService(networkService: networkService, userManager: userManager)
        }
        
        let testUser = SavedUser(
            id: "test-user-1",
            email: "test@example.com",
            name: "Test User",
            serverURL: "https://example.com",
            authType: .apiKey
        )
        
        await MainActor.run {
            networkService.baseURL = "https://example.com"
            networkService.accessToken = "api-key-123"
            userManager.currentUser = testUser
        }
        
        // Wait for async update
        try await Task.sleep(nanoseconds: 100_000_000)
        
        let headers = await MainActor.run {
            authService.getAuthHeaders()
        }
        #expect(headers["x-api-key"] == "api-key-123")
        #expect(headers["Authorization"] == nil)
    }
    
    @Test("AuthenticationService should return empty headers when no token")
    func testGetAuthHeadersNoToken() async {
        let userManager = UserManager(storage: MockUserStorage())
        let networkService = NetworkService(userManager: userManager)
        
        let authService = await MainActor.run {
            AuthenticationService(networkService: networkService, userManager: userManager)
        }
        
        await MainActor.run {
            networkService.accessToken = nil
        }
        
        let headers = await MainActor.run {
            authService.getAuthHeaders()
        }
        #expect(headers.isEmpty)
    }
    
    @Test("AuthenticationService should provide baseURL and accessToken")
    func testBaseURLAndAccessToken() async {
        let userManager = UserManager(storage: MockUserStorage())
        let networkService = NetworkService(userManager: userManager)
        
        let authService = await MainActor.run {
            AuthenticationService(networkService: networkService, userManager: userManager)
        }
        
        await MainActor.run {
            networkService.baseURL = "https://example.com"
            networkService.accessToken = "token-123"
        }
        
        await MainActor.run {
            #expect(authService.baseURL == "https://example.com")
            #expect(authService.accessToken == "token-123")
        }
    }
    
    @Test("AuthenticationService should clear credentials")
    func testClearCredentials() async throws {
        let userManager = UserManager(storage: MockUserStorage())
        let networkService = NetworkService(userManager: userManager)
        
        let authService = await MainActor.run {
            AuthenticationService(networkService: networkService, userManager: userManager)
        }
        
        await MainActor.run {
            networkService.baseURL = "https://example.com"
            networkService.accessToken = "token-123"
        }
        
        await MainActor.run {
            authService.clearCredentials()
        }
        
        // Wait for async operation to complete
        try await Task.sleep(nanoseconds: 100_000_000)
        
        await MainActor.run {
            #expect(networkService.baseURL.isEmpty)
            #expect(networkService.accessToken == nil)
        }
    }
    
    @Test("AuthenticationService should update credentials from current user")
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
        
        let authService = await MainActor.run {
            AuthenticationService(networkService: networkService, userManager: userManager)
        }
        
        await MainActor.run {
            authService.updateCredentialsFromCurrentUser()
        }
        
        // Wait for async updates
        try await Task.sleep(nanoseconds: 100_000_000)
        
        await MainActor.run {
            #expect(networkService.baseURL == "https://example.com")
            #expect(networkService.accessToken == "test-token-123")
        }
    }
}

