import Foundation
import SwiftUI
import Combine

/// Mode for the sign-in view
enum SignInMode {
    case signIn
    case addUser
}

@MainActor
class SignInViewModel: ObservableObject {
    // MARK: - Published Properties (Form State)
    @Published var serverURL = "https://immich.app:2283"
    @Published var email = ""
    @Published var password = ""
    @Published var apiKey = ""
    @Published var showApiKeyLogin = false
    
    // MARK: - Published Properties (UI State)
    @Published var isLoading = false
    @Published var showError = false
    @Published var errorMessage = ""
    
    // MARK: - Dependencies
    private let authService: AuthenticationService
    private let userManager: UserManager
    
    // MARK: - Configuration
    let mode: SignInMode
    
    // MARK: - Callbacks
    var onUserAdded: (() -> Void)?
    var onDismiss: (() -> Void)?
    
    // MARK: - Computed Properties
    
    var canSignIn: Bool {
        !isLoading && !serverURL.isEmpty && !email.isEmpty && (showApiKeyLogin ? !apiKey.isEmpty : !password.isEmpty)
    }
    
    var headerTitle: String {
        mode == .addUser ? "Add Account" : "Welcome Back"
    }
    
    var headerSubtitle: String {
        mode == .addUser ? "Connect another Immich server" : "Sign in to continue"
    }
    
    var buttonTitle: String {
        if isLoading {
            return mode == .addUser ? "Adding..." : "Signing In..."
        }
        return mode == .addUser ? "Add Account" : "Sign In"
    }
    
    var buttonIcon: String {
        mode == .addUser ? "person.badge.plus" : "arrow.right"
    }
    
    var alertTitle: String {
        mode == .addUser ? "Add User Error" : "Sign In Error"
    }
    
    // MARK: - Initialization
    
    init(
        authService: AuthenticationService,
        userManager: UserManager,
        mode: SignInMode = .signIn,
        onUserAdded: (() -> Void)? = nil,
        onDismiss: (() -> Void)? = nil
    ) {
        self.authService = authService
        self.userManager = userManager
        self.mode = mode
        self.onUserAdded = onUserAdded
        self.onDismiss = onDismiss
    }
    
    // MARK: - Public Methods
    
    /// Toggles between password and API key login modes
    func toggleLoginMode() {
        showApiKeyLogin.toggle()
        // Clear the other field when switching
        if showApiKeyLogin {
            password = ""
        } else {
            apiKey = ""
        }
    }
    
    /// Performs the sign-in or add user operation
    func signIn() {
        guard canSignIn else { return }
        
        isLoading = true
        
        // Clean up the server URL
        let cleanURL = cleanServerURL(serverURL)
        
        // Validate URL format
        guard URL(string: cleanURL) != nil else {
            isLoading = false
            showError = true
            errorMessage = "Please enter a valid server URL"
            return
        }
        
        Task {
            if mode == .addUser {
                await performAddUser(cleanURL: cleanURL)
            } else {
                await performSignIn(cleanURL: cleanURL)
            }
        }
    }
    
    // MARK: - Private Methods
    
    private func cleanServerURL(_ url: String) -> String {
        var cleanURL = url.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Add https:// if no protocol specified
        if !cleanURL.hasPrefix("http://") && !cleanURL.hasPrefix("https://") {
            cleanURL = "https://" + cleanURL
        }
        
        // Remove trailing slash if present
        if cleanURL.hasSuffix("/") {
            cleanURL = String(cleanURL.dropLast())
        }
        
        return cleanURL
    }
    
    private func performAddUser(cleanURL: String) async {
        do {
            // Authenticate and save user
            if showApiKeyLogin {
                _ = try await userManager.authenticateWithApiKey(
                    serverURL: cleanURL,
                    email: email,
                    apiKey: apiKey
                )
            } else {
                _ = try await userManager.authenticateWithCredentials(
                    serverURL: cleanURL,
                    email: email,
                    password: password
                )
            }
            
            // Find the newly added user
            let newUser = userManager.findUser(email: email, serverURL: cleanURL)
            
            // Switch to the new user
            if let newUser = newUser {
                try await authService.switchUser(newUser)
                
                // Refresh the app after switching users
                NotificationCenter.default.post(
                    name: NSNotification.Name(NotificationNames.refreshAllTabs),
                    object: nil
                )
            }
            
            onUserAdded?()
            onDismiss?()
            isLoading = false
        } catch {
            isLoading = false
            showError = true
            errorMessage = error.localizedDescription
        }
    }
    
    private func performSignIn(cleanURL: String) async {
        if showApiKeyLogin {
            authService.signInWithApiKey(serverURL: cleanURL, email: email, apiKey: apiKey) { [weak self] success, error in
                Task { @MainActor in
                    guard let self = self else { return }
                    self.isLoading = false
                    
                    if !success {
                        self.showError = true
                        self.errorMessage = error ?? "Failed to sign in. Please check your API key and try again."
                    }
                }
            }
        } else {
            authService.signIn(serverURL: cleanURL, email: email, password: password) { [weak self] success, error in
                Task { @MainActor in
                    guard let self = self else { return }
                    self.isLoading = false
                    
                    if !success {
                        self.showError = true
                        self.errorMessage = error ?? "Failed to sign in. Please check your credentials and try again."
                    }
                }
            }
        }
    }
}

