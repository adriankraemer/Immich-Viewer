import Foundation
@testable import Immich_Viewer

/// Mock implementation of UserStorage for testing
class MockUserStorage: UserStorageWithTokens {
    private var users: [String: SavedUser] = [:]
    private var tokens: [String: String] = [:]
    
    func saveUser(_ user: SavedUser) throws {
        users[user.id] = user
    }
    
    func loadUsers() -> [SavedUser] {
        return Array(users.values).sorted { $0.createdAt > $1.createdAt }
    }
    
    func removeUser(withId id: String) throws {
        users.removeValue(forKey: id)
        tokens.removeValue(forKey: id)
    }
    
    func removeAllUserData() throws {
        users.removeAll()
        tokens.removeAll()
    }
    
    // Additional methods for token management (used by HybridUserStorage)
    func saveToken(_ token: String, forUserId id: String) throws {
        tokens[id] = token
    }
    
    func getToken(forUserId id: String) -> String? {
        return tokens[id]
    }
    
    func removeToken(forUserId id: String) throws {
        tokens.removeValue(forKey: id)
    }
    
    func removeAllTokens() throws {
        tokens.removeAll()
    }
    
    // Helper methods for test setup
    func clearAll() {
        users.removeAll()
        tokens.removeAll()
    }
    
    func hasUser(withId id: String) -> Bool {
        return users[id] != nil
    }
    
    func hasToken(forUserId id: String) -> Bool {
        return tokens[id] != nil
    }
}

