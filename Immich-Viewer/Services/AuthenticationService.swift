import Foundation

/// Service responsible for authentication and user management
@MainActor
class AuthenticationService: ObservableObject {
    @Published var isAuthenticated = false
    @Published var currentUser: Owner?
    
    private let networkService: NetworkService
    private let userManager: UserManager
    
    // Public access to network service properties
    var baseURL: String {
        return networkService.baseURL
    }
    
    var accessToken: String? {
        return networkService.accessToken
    }
    
    /// Returns the appropriate authentication headers based on current user's auth type
    func getAuthHeaders() -> [String: String] {
        guard let accessToken = networkService.accessToken else {
            return [:]
        }
        
        // Check current user's auth type through userManager
        let isApiKey = userManager.currentUser?.authType == .apiKey
        
        if isApiKey {
            return ["x-api-key": accessToken]
        } else {
            return ["Authorization": "Bearer \(accessToken)"]
        }
    }
    
    init(networkService: NetworkService, userManager: UserManager) {
        self.networkService = networkService
        self.userManager = userManager
        self.isAuthenticated = userManager.hasCurrentUser
        debugLog("AuthenticationService: Initialized with isAuthenticated: \(isAuthenticated), hasCurrentUser: \(userManager.hasCurrentUser)")
        
        // Update network service with current user credentials if available
        networkService.updateCredentialsFromCurrentUser()
        
        validateTokenIfNeeded()
    }
    
    // MARK: - Authentication
    func signIn(serverURL: String, email: String, password: String, completion: @escaping (Bool, String?) -> Void) {
        Task {
            do {
                _ = try await userManager.authenticateWithCredentials(
                    serverURL: serverURL,
                    email: email,
                    password: password
                )
                
                // Update network service with current user credentials
                networkService.updateCredentialsFromCurrentUser()
                
                await MainActor.run {
                    self.isAuthenticated = true
                    debugLog("AuthenticationService: Successfully authenticated user: \(email)")
                }
                
                // Fetch user details
                do {
                    try await self.fetchUserInfo()
                } catch {
                    // Create fallback user object from saved user
                    if let savedUser = userManager.findUser(email: email, serverURL: serverURL) {
                        await MainActor.run {
                            self.currentUser = Owner(
                                id: savedUser.id,
                                email: savedUser.email,
                                name: savedUser.name,
                                profileImagePath: "",
                                profileChangedAt: "",
                                avatarColor: "primary"
                            )
                        }
                    }
                }
                
                await MainActor.run {
                    completion(true, nil)
                }
                
            } catch {
                await MainActor.run {
                    completion(false, error.localizedDescription)
                }
            }
        }
    }
    
    func signInWithApiKey(serverURL: String, email: String, apiKey: String, completion: @escaping (Bool, String?) -> Void) {
        Task {
            do {
                _ = try await userManager.authenticateWithApiKey(
                    serverURL: serverURL,
                    email: email,
                    apiKey: apiKey
                )
                
                // Update network service with current user credentials
                networkService.updateCredentialsFromCurrentUser()
                
                await MainActor.run {
                    self.isAuthenticated = true
                    debugLog("AuthenticationService: Successfully authenticated user with API key: \(email)")
                }
                
                // Fetch user details
                do {
                    try await self.fetchUserInfo()
                } catch {
                    // Create fallback user object from saved user
                    if let savedUser = userManager.findUser(email: email, serverURL: serverURL) {
                        await MainActor.run {
                            self.currentUser = Owner(
                                id: savedUser.id,
                                email: savedUser.email,
                                name: savedUser.name,
                                profileImagePath: "",
                                profileChangedAt: "",
                                avatarColor: "primary"
                            )
                        }
                    }
                }
                
                await MainActor.run {
                    completion(true, nil)
                }
                
            } catch {
                await MainActor.run {
                    completion(false, error.localizedDescription)
                }
            }
        }
    }
    
    /// Internal sign out method - logs out current user and switches to next available user if any exist
    /// For UI-initiated logout, use UserManager.logoutCurrentUser() directly
    /// Handles multi-user scenarios by automatically switching to another user if available
    func signOut() {
        debugLog("AuthenticationService: Signing out user")
        
        Task {
            do {
                // Logout current user from UserManager (switches to another user if available)
                try await userManager.logoutCurrentUser()
                
                // Check if we still have a current user after logout (multi-user scenario)
                if userManager.hasCurrentUser {
                    // Switch to the next available user
                    debugLog("AuthenticationService: Switching to next available user after logout")
                    networkService.updateCredentialsFromCurrentUser()
                    
                    await MainActor.run {
                        self.isAuthenticated = true
                    }
                    
                    // Fetch the new current user info
                    try await fetchUserInfo()
                } else {
                    // No users left, fully sign out
                    debugLog("AuthenticationService: No users left, fully signing out")
                    networkService.clearCredentials()
                    
                    await MainActor.run {
                        self.isAuthenticated = false
                        self.currentUser = nil
                    }
                }
                
                debugLog("AuthenticationService: Successfully completed signout process")
            } catch {
                debugLog("AuthenticationService: Error during signout: \(error)")
                
                // Even if logout fails, still clear the auth state to prevent inconsistent state
                networkService.clearCredentials()
                await MainActor.run {
                    self.isAuthenticated = false
                    self.currentUser = nil
                }
            }
        }
    }
    
    func switchUser(_ user: SavedUser) async throws {
        _ = try await userManager.switchToUser(user)
        
        // Update network service with current user credentials
        networkService.updateCredentialsFromCurrentUser()
        
        await MainActor.run {
            self.isAuthenticated = true
            debugLog("AuthenticationService: Switched to user \(user.email)")
        }
        
        // Fetch user details from server
        do {
            try await fetchUserInfo()
        } catch {
            // Create fallback user object from saved user
            await MainActor.run {
                self.currentUser = Owner(
                    id: user.id,
                    email: user.email,
                    name: user.name,
                    profileImagePath: "",
                    profileChangedAt: "",
                    avatarColor: "primary"
                )
            }
        }
    }

    
    // MARK: - User Management
    
    /// Updates network credentials from current user
    func updateCredentialsFromCurrentUser() {
        networkService.updateCredentialsFromCurrentUser()
    }
    
    /// Clears network credentials
    func clearCredentials() {
        networkService.clearCredentials()
    }
    
    func fetchUserInfo() async throws {
        debugLog("AuthenticationService: Fetching user info from server")
        let user: User = try await networkService.makeRequest(
            endpoint: "/api/users/me",
            responseType: User.self
        )
        
        let owner = Owner(
            id: user.id,
            email: user.email,
            name: user.name,
            profileImagePath: user.profileImagePath,
            profileChangedAt: user.profileChangedAt,
            avatarColor: user.avatarColor
        )
        
        debugLog("AuthenticationService: Updating currentUser to \(owner.email)")
        self.currentUser = owner
    }
    
    /// Validates the current authentication token by fetching user info
    /// Automatically logs out if token is invalid, but preserves state for network/server errors
    private func validateTokenIfNeeded() {
        guard isAuthenticated && !networkService.baseURL.isEmpty else { 
            debugLog("AuthenticationService: Skipping token validation - not authenticated or no baseURL")
            return 
        }
        
        Task { @MainActor in
            do {
                try await fetchUserInfo()
                debugLog("AuthenticationService: Token validation successful")
            } catch let error as ImmichError {
                debugLog("AuthenticationService: Token validation failed with ImmichError: \(error)")
                
                if error.shouldLogout {
                    // Authentication errors (401/403) - logout and clear data
                    debugLog("AuthenticationService: Logging out user due to authentication error: \(error)")
                    self.signOut()
                    if let bundleID = Bundle.main.bundleIdentifier {
                        debugLog("removing all shared data")
                        UserDefaults.standard.removePersistentDomain(forName: bundleID)
                        UserDefaults.standard.removePersistentDomain(forName: AppConstants.appGroupIdentifier)
                        UserDefaults.standard.synchronize()
                    }
                } else {
                    // Server/network errors - preserve authentication state
                    // User will see error messages but won't be logged out
                    debugLog("AuthenticationService: Preserving authentication state despite error: \(error)")
                }
            } catch {
                // Unexpected errors - handle conservatively by preserving auth state
                debugLog("AuthenticationService: Token validation failed with unexpected error: \(error)")
            }
        }
    }
} 
