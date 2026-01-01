//
//  HybridUserStorageTests.swift
//  Immich-AppleTVTests
//
//  Created for testing purposes
//

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
        #expect(loadedUsers.count == 1)
        #expect(loadedUsers.first?.id == testUser.id)
        #expect(loadedUsers.first?.email == testUser.email)
        
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
        #expect(loadedUsers.isEmpty)
        
        let token = storage.getToken(forUserId: testUser.id)
        #expect(token == nil)
        
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
        #expect(loadedUsers.count >= 2, "Expected at least 2 users, got \(loadedUsers.count)")
        
        // Verify both users exist
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
        #expect(loadedUsers.isEmpty)
        
        #expect(storage.getToken(forUserId: user1.id) == nil)
        #expect(storage.getToken(forUserId: user2.id) == nil)
        
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
        #expect(loadedUsers.count == 1)
        
        // But token should be removed
        let token = storage.getToken(forUserId: testUser.id)
        #expect(token == nil)
        
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

