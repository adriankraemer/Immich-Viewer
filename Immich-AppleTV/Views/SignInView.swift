//
//  SignInView.swift
//  Immich-AppleTV
//
//  Created by Adrian Kraemer on 2025-06-29.
//

import SwiftUI

struct SignInView: View {
    @ObservedObject var authService: AuthenticationService
    @ObservedObject var userManager: UserManager
    let mode: Mode
    let onUserAdded: (() -> Void)?
    @Environment(\.dismiss) private var dismiss
    @State private var serverURL = "http://localhost:2283"
    @State private var email = ""
    @State private var password = ""
    @State private var apiKey = ""
    @State private var showApiKeyLogin = false
    @State private var isLoading = false
    @State private var showError = false
    @State private var errorMessage = ""
    @FocusState private var focusedField: Field?
    
    enum Field {
        case serverURL, email, password, apiKey, signInButton, apiKeyToggle
    }
    
    enum Mode {
        case signIn
        case addUser
    }
    
    // Brand colors from the logo
    private let brandPink = Color(red: 250/255, green: 79/255, blue: 163/255)
    private let brandOrange = Color(red: 255/255, green: 180/255, blue: 0/255)
    private let brandGreen = Color(red: 61/255, green: 220/255, blue: 151/255)
    private let brandBlue = Color(red: 76/255, green: 111/255, blue: 255/255)
    private let brandRed = Color(red: 250/255, green: 41/255, blue: 33/255)
    
    init(authService: AuthenticationService, userManager: UserManager, mode: Mode = .signIn, onUserAdded: (() -> Void)? = nil) {
        self.authService = authService
        self.userManager = userManager
        self.mode = mode
        self.onUserAdded = onUserAdded
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                // Rich gradient background
                backgroundGradient
                
                // Subtle pattern overlay
                patternOverlay
                
                // Main content
                HStack(spacing: 0) {
                    // Left side - Branding
                    brandingSection
                        .frame(width: 700)
                    
                    // Right side - Login form
                    formSection
                        .frame(maxWidth: .infinity)
                }
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }
    
    // MARK: - Background
    
    private var backgroundGradient: some View {
        ZStack {
            // Base dark gradient
            LinearGradient(
                colors: [
                    Color(red: 15/255, green: 17/255, blue: 23/255),
                    Color(red: 22/255, green: 27/255, blue: 34/255),
                    Color(red: 15/255, green: 17/255, blue: 23/255)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            
            // Accent glow from logo colors
            RadialGradient(
                colors: [
                    brandBlue.opacity(0.15),
                    Color.clear
                ],
                center: .bottomLeading,
                startRadius: 100,
                endRadius: 800
            )
            
            RadialGradient(
                colors: [
                    brandPink.opacity(0.1),
                    Color.clear
                ],
                center: .topTrailing,
                startRadius: 50,
                endRadius: 600
            )
        }
        .ignoresSafeArea()
    }
    
    private var patternOverlay: some View {
        GeometryReader { geo in
            Canvas { context, size in
                // Subtle dot grid pattern
                let spacing: CGFloat = 60
                let dotRadius: CGFloat = 1.5
                
                for x in stride(from: 0, to: size.width, by: spacing) {
                    for y in stride(from: 0, to: size.height, by: spacing) {
                        let rect = CGRect(x: x, y: y, width: dotRadius * 2, height: dotRadius * 2)
                        context.fill(
                            Path(ellipseIn: rect),
                            with: .color(.white.opacity(0.03))
                        )
                    }
                }
            }
        }
        .ignoresSafeArea()
    }
    
    // MARK: - Branding Section
    
    private var brandingSection: some View {
        VStack(spacing: 40) {
            Spacer()
            
            // Logo
            Image("icon")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 200, height: 200)
                .shadow(color: brandBlue.opacity(0.5), radius: 30, x: 0, y: 10)
            
            // App name with gradient
            VStack(spacing: 12) {
                Text("Immich")
                    .font(.system(size: 72, weight: .bold, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [brandPink, brandOrange, brandGreen, brandBlue],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                
                Text("for Apple TV")
                    .font(.system(size: 28, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.7))
            }
            
            // Tagline
            Text("Your memories, beautifully displayed")
                .font(.system(size: 22, weight: .regular, design: .rounded))
                .foregroundColor(.white.opacity(0.5))
                .padding(.top, 8)
            
            Spacer()
            
            // Footer hint
            VStack(spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: "shield.checkered")
                        .font(.system(size: 14))
                    Text("Self-hosted photo backup")
                        .font(.system(size: 14, weight: .medium))
                }
                .foregroundColor(.white.opacity(0.4))
            }
            .padding(.bottom, 60)
        }
        .padding(.horizontal, 60)
    }
    
    // MARK: - Form Section
    
    private var formSection: some View {
        VStack(spacing: 0) {
            Spacer()
            
            VStack(alignment: .leading, spacing: 32) {
                // Header
                VStack(alignment: .leading, spacing: 8) {
                    Text(mode == .addUser ? "Add Account" : "Welcome Back")
                        .font(.system(size: 42, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    
                    Text(mode == .addUser ? "Connect another Immich server" : "Sign in to continue")
                        .font(.system(size: 20, weight: .regular))
                        .foregroundColor(.white.opacity(0.6))
                }
                
                // Form fields
                VStack(spacing: 24) {
                    // Server URL
                    formField(
                        icon: "server.rack",
                        title: "Server URL",
                        placeholder: "https://your-immich-server.com",
                        text: $serverURL,
                        isSecure: false,
                        keyboardType: .URL,
                        field: .serverURL
                    )
                    
                    // Email
                    formField(
                        icon: "envelope",
                        title: "Email",
                        placeholder: "your-email@example.com",
                        text: $email,
                        isSecure: false,
                        keyboardType: .emailAddress,
                        field: .email
                    )
                    
                    // Password or API Key
                    if showApiKeyLogin {
                        formField(
                            icon: "key",
                            title: "API Key",
                            placeholder: "Enter your API key",
                            text: $apiKey,
                            isSecure: true,
                            keyboardType: .default,
                            field: .apiKey
                        )
                    } else {
                        formField(
                            icon: "lock",
                            title: "Password",
                            placeholder: "Enter your password",
                            text: $password,
                            isSecure: true,
                            keyboardType: .default,
                            field: .password
                        )
                    }
                }
                
                // Sign In Button
                signInButton
                    .padding(.top, 8)
                
                // API Key toggle
                apiKeyToggle
                    .padding(.top, 4)
            }
            .frame(width: 600)
            .padding(50)
            .background(
                RoundedRectangle(cornerRadius: 32)
                    .fill(Color.white.opacity(0.03))
                    .overlay(
                        RoundedRectangle(cornerRadius: 32)
                            .strokeBorder(
                                LinearGradient(
                                    colors: [.white.opacity(0.1), .white.opacity(0.02)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    )
            )
            
            Spacer()
            
            // Help text
            Text("Make sure your Immich server is accessible from this device")
                .font(.system(size: 14))
                .foregroundColor(.white.opacity(0.3))
                .padding(.bottom, 40)
        }
        .padding(.horizontal, 80)
        .alert(mode == .addUser ? "Add User Error" : "Sign In Error", isPresented: $showError) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
        }
    }
    
    // MARK: - Form Field
    
    private func formField(
        icon: String,
        title: String,
        placeholder: String,
        text: Binding<String>,
        isSecure: Bool,
        keyboardType: UIKeyboardType,
        field: Field
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            // Label
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(brandBlue)
                
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white.opacity(0.8))
            }
            
            // Input field
            Group {
                if isSecure {
                    SecureField(placeholder, text: text)
                } else {
                    TextField(placeholder, text: text)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                        .keyboardType(keyboardType)
                }
            }
            .font(.system(size: 24, weight: .regular))
            .padding(.horizontal, 24)
            .padding(.vertical, 20)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.white.opacity(0.05))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
                    )
            )
            .focused($focusedField, equals: field)
        }
    }
    
    // MARK: - Sign In Button
    
    private var signInButton: some View {
        Button(action: signIn) {
            HStack(spacing: 12) {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.9)
                } else {
                    Image(systemName: mode == .addUser ? "person.badge.plus" : "arrow.right")
                        .font(.system(size: 20, weight: .semibold))
                }
                
                Text(isLoading ? (mode == .addUser ? "Adding..." : "Signing In...") : (mode == .addUser ? "Add Account" : "Sign In"))
                    .font(.system(size: 22, weight: .semibold, design: .rounded))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 22)
            .background(
                LinearGradient(
                    colors: canSignIn ? [brandBlue, brandBlue.opacity(0.8)] : [Color.gray.opacity(0.3), Color.gray.opacity(0.2)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .foregroundColor(.white)
            .cornerRadius(16)
            .shadow(color: canSignIn ? brandBlue.opacity(0.4) : .clear, radius: 20, x: 0, y: 10)
        }
        .buttonStyle(CardButtonStyle())
        .disabled(!canSignIn)
        .focused($focusedField, equals: .signInButton)
    }
    
    private var canSignIn: Bool {
        !isLoading && !serverURL.isEmpty && !email.isEmpty && (showApiKeyLogin ? !apiKey.isEmpty : !password.isEmpty)
    }
    
    // MARK: - API Key Toggle
    
    private var apiKeyToggle: some View {
        Button(action: {
            withAnimation(.easeInOut(duration: 0.3)) {
                showApiKeyLogin.toggle()
                // Clear the other field when switching
                if showApiKeyLogin {
                    password = ""
                } else {
                    apiKey = ""
                }
            }
        }) {
            HStack(spacing: 8) {
                Image(systemName: showApiKeyLogin ? "person.fill" : "key.fill")
                    .font(.system(size: 14))
                
                Text(showApiKeyLogin ? "Use password instead" : "Use API key instead")
                    .font(.system(size: 16, weight: .medium))
            }
            .foregroundColor(.white.opacity(0.5))
            .padding(.vertical, 12)
            .padding(.horizontal, 20)
            .background(
                Capsule()
                    .fill(Color.white.opacity(0.05))
            )
        }
        .buttonStyle(CardButtonStyle())
        .focused($focusedField, equals: .apiKeyToggle)
    }
    
    // MARK: - Sign In Logic
    
    private func signIn() {
        guard canSignIn else { return }
        
        isLoading = true
        
        // Clean up the server URL
        var cleanURL = serverURL.trimmingCharacters(in: .whitespacesAndNewlines)
        if !cleanURL.hasPrefix("http://") && !cleanURL.hasPrefix("https://") {
            cleanURL = "https://" + cleanURL
        }
        
        // Remove trailing slash if present
        if cleanURL.hasSuffix("/") {
            cleanURL = String(cleanURL.dropLast())
        }
        
        // Validate URL format
        guard URL(string: cleanURL) != nil else {
            isLoading = false
            showError = true
            errorMessage = "Please enter a valid server URL"
            return
        }
        
        Task {
            do {
                if mode == .addUser {
                    // Add user mode: authenticate, save user, and switch to them
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
                        await MainActor.run {
                            NotificationCenter.default.post(name: NSNotification.Name(NotificationNames.refreshAllTabs), object: nil)
                        }
                    }
                    
                    await MainActor.run {
                        onUserAdded?()
                        dismiss()
                        isLoading = false
                    }
                } else {
                    // Regular sign in mode: use the existing auth service
                    if showApiKeyLogin {
                        authService.signInWithApiKey(serverURL: cleanURL, email: email, apiKey: apiKey) { success, error in
                            DispatchQueue.main.async {
                                isLoading = false
                                
                                if !success {
                                    showError = true
                                    errorMessage = error ?? "Failed to sign in. Please check your API key and try again."
                                }
                            }
                        }
                    } else {
                        authService.signIn(serverURL: cleanURL, email: email, password: password) { success, error in
                            DispatchQueue.main.async {
                                isLoading = false
                                
                                if !success {
                                    showError = true
                                    errorMessage = error ?? "Failed to sign in. Please check your credentials and try again."
                                }
                            }
                        }
                    }
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    showError = true
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
    
}

#Preview {
    let userManager = UserManager()
    let networkService = NetworkService(userManager: userManager)
    let authService = AuthenticationService(networkService: networkService, userManager: userManager)
    SignInView(authService: authService, userManager: userManager, mode: .signIn)
}
