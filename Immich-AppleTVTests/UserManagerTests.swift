//
//  UserManagerTests.swift
//  Immich-AppleTVTests
//
//  Created for testing purposes
//

import Testing
import Foundation
@testable import Immich_AppleTV

@Suite("UserManager Tests")
struct UserManagerTests {
    
    @Test("UserManager should initialize with empty users")
    func testInitialization() async throws {
        let storage = MockUserStorage()
        let userManager = UserManager(storage: storage)
        
        #expect(userManager.savedUsers.isEmpty)
        #expect(userManager.currentUser == nil)
        #expect(userManager.hasCurrentUser == false)
    }
    
    @Test("UserManager should save and load users")
    func testSaveAndLoadUser() async throws {
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
        
        #expect(userManager.savedUsers.count == 1)
        #expect(userManager.savedUsers.first?.id == testUser.id)
        #expect(userManager.savedUsers.first?.email == testUser.email)
        #expect(storage.hasToken(forUserId: testUser.id) == true)
    }
    
    @Test("UserManager should find user by email and server URL")
    func testFindUser() async throws {
        let storage = MockUserStorage()
        let userManager = UserManager(storage: storage)
        
        let testUser = SavedUser(
            id: "test-user-1",
            email: "test@example.com",
            name: "Test User",
            serverURL: "https://example.com",
            authType: .jwt
        )
        
        try await userManager.saveUser(testUser, token: "test-token")
        
        let foundUser = userManager.findUser(email: "test@example.com", serverURL: "https://example.com")
        #expect(foundUser != nil)
        #expect(foundUser?.id == testUser.id)
        
        let notFoundUser = userManager.findUser(email: "other@example.com", serverURL: "https://example.com")
        #expect(notFoundUser == nil)
    }
    
    @Test("UserManager should check if user exists")
    func testUserExists() async throws {
        let storage = MockUserStorage()
        let userManager = UserManager(storage: storage)
        
        let testUser = SavedUser(
            id: "test-user-1",
            email: "test@example.com",
            name: "Test User",
            serverURL: "https://example.com",
            authType: .jwt
        )
        
        try await userManager.saveUser(testUser, token: "test-token")
        
        #expect(userManager.userExists(email: "test@example.com", serverURL: "https://example.com") == true)
        #expect(userManager.userExists(email: "other@example.com", serverURL: "https://example.com") == false)
    }
    
    @Test("UserManager should switch between users")
    func testSwitchUser() async throws {
        let storage = MockUserStorage()
        let userManager = UserManager(storage: storage)
        
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
        
        try await userManager.saveUser(user1, token: "token-1")
        try await userManager.saveUser(user2, token: "token-2")
        
        // Set user1 as current
        await MainActor.run {
            userManager.currentUser = user1
        }
        
        // Switch to user2
        let token = try await userManager.switchToUser(user2)
        
        #expect(token == "token-2")
        #expect(userManager.currentUser?.id == user2.id)
        #expect(userManager.currentUser?.email == user2.email)
    }
    
    @Test("UserManager should remove user")
    func testRemoveUser() async throws {
        let storage = MockUserStorage()
        let userManager = UserManager(storage: storage)
        
        let testUser = SavedUser(
            id: "test-user-1",
            email: "test@example.com",
            name: "Test User",
            serverURL: "https://example.com",
            authType: .jwt
        )
        
        try await userManager.saveUser(testUser, token: "test-token")
        #expect(userManager.savedUsers.count == 1)
        
        try await userManager.removeUser(testUser)
        
        #expect(userManager.savedUsers.isEmpty)
        #expect(storage.hasUser(withId: testUser.id) == false)
        #expect(storage.hasToken(forUserId: testUser.id) == false)
    }
    
    @Test("UserManager should switch to next user when current user is removed")
    func testRemoveCurrentUserSwitchesToNext() async throws {
        let storage = MockUserStorage()
        let userManager = UserManager(storage: storage)
        
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
        
        try await userManager.saveUser(user1, token: "token-1")
        try await userManager.saveUser(user2, token: "token-2")
        
        await MainActor.run {
            userManager.currentUser = user1
        }
        
        try await userManager.removeUser(user1)
        
        // Should switch to user2
        #expect(userManager.currentUser?.id == user2.id)
        #expect(userManager.savedUsers.count == 1)
    }
    
    @Test("UserManager should clear all users")
    func testClearAllUsers() async throws {
        let storage = MockUserStorage()
        let userManager = UserManager(storage: storage)
        
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
        
        try await userManager.saveUser(user1, token: "token-1")
        try await userManager.saveUser(user2, token: "token-2")
        
        #expect(userManager.savedUsers.count == 2)
        
        try await userManager.clearAllUsers()
        
        #expect(userManager.savedUsers.isEmpty)
        #expect(userManager.currentUser == nil)
        #expect(userManager.hasCurrentUser == false)
    }
    
    @Test("UserManager should get users for specific server")
    func testGetUsersForServer() async throws {
        let storage = MockUserStorage()
        let userManager = UserManager(storage: storage)
        
        let user1 = SavedUser(
            id: "user-1",
            email: "user1@example.com",
            name: "User 1",
            serverURL: "https://server1.com",
            authType: .jwt
        )
        
        let user2 = SavedUser(
            id: "user-2",
            email: "user2@example.com",
            name: "User 2",
            serverURL: "https://server2.com",
            authType: .jwt
        )
        
        let user3 = SavedUser(
            id: "user-3",
            email: "user3@example.com",
            name: "User 3",
            serverURL: "https://server1.com",
            authType: .jwt
        )
        
        try await userManager.saveUser(user1, token: "token-1")
        try await userManager.saveUser(user2, token: "token-2")
        try await userManager.saveUser(user3, token: "token-3")
        
        let server1Users = userManager.getUsersForServer("https://server1.com")
        #expect(server1Users.count == 2)
        #expect(server1Users.allSatisfy { $0.serverURL == "https://server1.com" })
        
        let server2Users = userManager.getUsersForServer("https://server2.com")
        #expect(server2Users.count == 1)
        #expect(server2Users.first?.serverURL == "https://server2.com")
    }
    
    @Test("UserManager should provide current user properties")
    func testCurrentUserProperties() async throws {
        let storage = MockUserStorage()
        let userManager = UserManager(storage: storage)
        
        let testUser = SavedUser(
            id: "test-user-1",
            email: "test@example.com",
            name: "Test User",
            serverURL: "https://example.com",
            authType: .apiKey
        )
        
        try await userManager.saveUser(testUser, token: "test-token-123")
        
        await MainActor.run {
            userManager.currentUser = testUser
        }
        
        #expect(userManager.currentUserToken == "test-token-123")
        #expect(userManager.currentUserServerURL == "https://example.com")
        #expect(userManager.currentUserAuthType == .apiKey)
        #expect(userManager.hasCurrentUser == true)
    }
    
    @Test("UserManager should handle logout of current user")
    func testLogoutCurrentUser() async throws {
        let storage = MockUserStorage()
        let userManager = UserManager(storage: storage)
        
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
        
        try await userManager.saveUser(user1, token: "token-1")
        try await userManager.saveUser(user2, token: "token-2")
        
        await MainActor.run {
            userManager.currentUser = user1
        }
        
        try await userManager.logoutCurrentUser()
        
        // Should switch to user2
        #expect(userManager.currentUser?.id == user2.id)
        #expect(userManager.savedUsers.count == 1)
        #expect(userManager.savedUsers.first?.id == user2.id)
    }
}

