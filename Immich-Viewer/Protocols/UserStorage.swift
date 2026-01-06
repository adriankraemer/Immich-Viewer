import Foundation

/// Protocol for user data storage abstraction
/// Allows different storage implementations (UserDefaults, Core Data, etc.)
protocol UserStorage {
    func saveUser(_ user: SavedUser) throws
    func loadUsers() -> [SavedUser]
    func removeUser(withId id: String) throws
    func removeAllUserData() throws
}

/// Extended protocol that includes token management methods
/// Used by UserManager which needs both user and token storage capabilities
/// Tokens are typically stored separately (e.g., Keychain) for security
protocol UserStorageWithTokens: UserStorage {
    func saveToken(_ token: String, forUserId id: String) throws
    func getToken(forUserId id: String) -> String?
    func removeToken(forUserId id: String) throws
}
