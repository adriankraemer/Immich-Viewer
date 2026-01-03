import Testing
import Foundation
@testable import Immich_AppleTV

@Suite("HybridUserStorage Tests")
struct HybridUserStorageTests {
    
    @Test("HybridUserStorage should save and load users")
    func testSaveAndLoadUser() throws {
        let storage = HybridUserStorage()
        
        // Clean up any existing test data
        try? storage.removeAllUserData()
        
        let testUser = SavedUser(
            id: "test-user-1",
            email: "test@example.com",
            name: "Test User",
            serverURL: "https://example.com",
            authType: .jwt
        )
        
        try storage.saveUser(testUser)
        
        let loadedUsers = storage.loadUsers()
        // Check that our specific user exists (may be more users from other tests)
        let foundUser = loadedUsers.first { $0.id == testUser.id }
        #expect(foundUser != nil, "Test user not found in loaded users")
        #expect(foundUser?.id == testUser.id)
        #expect(foundUser?.email == testUser.email)
        
        // Clean up after test
        try? storage.removeAllUserData()
    }
    
    @Test("HybridUserStorage should save and retrieve tokens")
    func testSaveAndGetToken() throws {
        let storage = HybridUserStorage()
        
        // Clean up any existing test data
        try? storage.removeAllUserData()
        
        let testUser = SavedUser(
            id: "test-user-1",
            email: "test@example.com",
            name: "Test User",
            serverURL: "https://example.com",
            authType: .jwt
        )
        
        try storage.saveUser(testUser)
        try storage.saveToken("test-token-123", forUserId: testUser.id)
        
        let token = storage.getToken(forUserId: testUser.id)
        #expect(token == "test-token-123")
        
        // Clean up after test
        try? storage.removeAllUserData()
    }
    
    @Test("HybridUserStorage should remove user and associated token")
    func testRemoveUser() throws {
        let storage = HybridUserStorage()
        
        // Clean up any existing test data
        try? storage.removeAllUserData()
        
        let testUser = SavedUser(
            id: "test-user-1",
            email: "test@example.com",
            name: "Test User",
            serverURL: "https://example.com",
            authType: .jwt
        )
        
        try storage.saveUser(testUser)
        try storage.saveToken("test-token-123", forUserId: testUser.id)
        
        try storage.removeUser(withId: testUser.id)
        
        let loadedUsers = storage.loadUsers()
        // Check that our specific user was removed (may be other users from other tests)
        let foundUser = loadedUsers.first { $0.id == testUser.id }
        #expect(foundUser == nil, "Test user should be removed")
        
        let token = storage.getToken(forUserId: testUser.id)
        #expect(token == nil, "Token should be removed with user")
        
        // Clean up after test
        try? storage.removeAllUserData()
    }
    
    @Test("HybridUserStorage should handle multiple users")
    func testMultipleUsers() throws {
        let storage = HybridUserStorage()
        
        // Clean up any existing test data
        try? storage.removeAllUserData()
        
        let user1 = SavedUser(
            id: "user-1",
            email: "user1@example.com",
            name: "User 1",
            serverURL: "https://example.com",
            authType: .jwt
        )
        
        let user2 = SavedUser(
            id: "user-2",
            email: "user2@example.com",
            name: "User 2",
            serverURL: "https://example.com",
            authType: .apiKey
        )
        
        try storage.saveUser(user1)
        try storage.saveUser(user2)
        try storage.saveToken("token-1", forUserId: user1.id)
        try storage.saveToken("token-2", forUserId: user2.id)
        
        let loadedUsers = storage.loadUsers()
        
        // Verify both users exist (may be more users from other tests)
        let foundUser1 = loadedUsers.first { $0.id == user1.id }
        let foundUser2 = loadedUsers.first { $0.id == user2.id }
        #expect(foundUser1 != nil, "User 1 not found in loaded users")
        #expect(foundUser2 != nil, "User 2 not found in loaded users")
        
        #expect(storage.getToken(forUserId: user1.id) == "token-1")
        #expect(storage.getToken(forUserId: user2.id) == "token-2")
        
        // Clean up after test
        try? storage.removeAllUserData()
    }
    
    @Test("HybridUserStorage should remove all user data")
    func testRemoveAllUserData() throws {
        let storage = HybridUserStorage()
        
        // Clean up any existing test data
        try? storage.removeAllUserData()
        
        let user1 = SavedUser(
            id: "user-1",
            email: "user1@example.com",
            name: "User 1",
            serverURL: "https://example.com",
            authType: .jwt
        )
        
        let user2 = SavedUser(
            id: "user-2",
            email: "user2@example.com",
            name: "User 2",
            serverURL: "https://example.com",
            authType: .jwt
        )
        
        try storage.saveUser(user1)
        try storage.saveUser(user2)
        try storage.saveToken("token-1", forUserId: user1.id)
        try storage.saveToken("token-2", forUserId: user2.id)
        
        try storage.removeAllUserData()
        
        let loadedUsers = storage.loadUsers()
        // Check that our specific users were removed (may be other users from other tests)
        let foundUser1 = loadedUsers.first { $0.id == user1.id }
        let foundUser2 = loadedUsers.first { $0.id == user2.id }
        #expect(foundUser1 == nil, "User 1 should be removed")
        #expect(foundUser2 == nil, "User 2 should be removed")
        
        #expect(storage.getToken(forUserId: user1.id) == nil, "Token 1 should be removed")
        #expect(storage.getToken(forUserId: user2.id) == nil, "Token 2 should be removed")
        
        // Clean up after test (should already be clean, but ensure it)
        try? storage.removeAllUserData()
    }
    
    @Test("HybridUserStorage should handle token removal separately")
    func testRemoveToken() throws {
        let storage = HybridUserStorage()
        
        // Clean up any existing test data
        try? storage.removeAllUserData()
        
        let testUser = SavedUser(
            id: "test-user-1",
            email: "test@example.com",
            name: "Test User",
            serverURL: "https://example.com",
            authType: .jwt
        )
        
        try storage.saveUser(testUser)
        try storage.saveToken("test-token-123", forUserId: testUser.id)
        
        try storage.removeToken(forUserId: testUser.id)
        
        // User should still exist
        let loadedUsers = storage.loadUsers()
        let foundUser = loadedUsers.first { $0.id == testUser.id }
        #expect(foundUser != nil, "Test user should still exist after token removal")
        
        // But token should be removed
        let token = storage.getToken(forUserId: testUser.id)
        #expect(token == nil, "Token should be removed")
        
        // Clean up after test
        try? storage.removeAllUserData()
    }
    
    @Test("HybridUserStorage should return nil for non-existent token")
    func testGetNonExistentToken() throws {
        let storage = HybridUserStorage()
        
        let token = storage.getToken(forUserId: "non-existent-id")
        #expect(token == nil)
    }
}

