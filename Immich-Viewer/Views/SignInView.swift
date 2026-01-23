import SwiftUI

struct SignInView: View {
    // MARK: - ViewModel
    @StateObject private var viewModel: SignInViewModel
    
    // MARK: - Environment
    @Environment(\.dismiss) private var dismiss
    @FocusState private var focusedField: Field?
    
    enum Field {
        case serverURL, email, password, apiKey, signInButton, apiKeyToggle
    }
    
    // MARK: - Brand Colors
    private let brandPink = Color(red: 250/255, green: 79/255, blue: 163/255)
    private let brandOrange = Color(red: 255/255, green: 180/255, blue: 0/255)
    private let brandGreen = Color(red: 61/255, green: 220/255, blue: 151/255)
    private let brandBlue = Color(red: 76/255, green: 111/255, blue: 255/255)
    private let brandRed = Color(red: 250/255, green: 41/255, blue: 33/255)
    
    // MARK: - Initialization
    
    /// Legacy initializer using Mode enum for backward compatibility
    init(authService: AuthenticationService, userManager: UserManager, mode: Mode = .signIn, onUserAdded: (() -> Void)? = nil) {
        let signInMode: SignInMode = mode == .addUser ? .addUser : .signIn
        _viewModel = StateObject(wrappedValue: SignInViewModel(
            authService: authService,
            userManager: userManager,
            mode: signInMode,
            onUserAdded: onUserAdded,
            onDismiss: nil
        ))
    }
    
    /// Legacy Mode enum for backward compatibility
    enum Mode {
        case signIn
        case addUser
    }
    
    // MARK: - Body
    
    var body: some View {
        NavigationView {
            ZStack {
                backgroundGradient
                patternOverlay
                
                HStack(spacing: 0) {
                    brandingSection
                        .frame(width: 700)
                    
                    formSection
                        .frame(maxWidth: .infinity)
                }
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .onAppear {
            // Set up dismiss callback
            viewModel.onDismiss = { dismiss() }
        }
        .onChange(of: viewModel.canSignIn) { _, canSignIn in
            // Auto-focus sign-in button when form becomes valid and user is in a credential field
            if canSignIn {
                let credentialFields: [Field] = [.password, .apiKey]
                if let currentField = focusedField, credentialFields.contains(currentField) {
                    focusedField = .signInButton
                }
            }
        }
    }
    
    // MARK: - Background
    
    private var backgroundGradient: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 15/255, green: 17/255, blue: 23/255),
                    Color(red: 22/255, green: 27/255, blue: 34/255),
                    Color(red: 15/255, green: 17/255, blue: 23/255)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            
            RadialGradient(
                colors: [brandBlue.opacity(0.15), Color.clear],
                center: .bottomLeading,
                startRadius: 100,
                endRadius: 800
            )
            
            RadialGradient(
                colors: [brandPink.opacity(0.1), Color.clear],
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
            
            Image("icon")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 200, height: 200)
                .shadow(color: brandBlue.opacity(0.5), radius: 30, x: 0, y: 10)
            
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
                
                Text(String(localized: "for Apple TV"))
                    .font(.system(size: 28, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.7))
            }
            
            Text(String(localized: "Your memories, beautifully displayed"))
                .font(.system(size: 22, weight: .regular, design: .rounded))
                .foregroundColor(.white.opacity(0.5))
                .padding(.top, 8)
            
            Spacer()
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
                    Text(viewModel.headerTitle)
                        .font(.system(size: 42, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    
                    Text(viewModel.headerSubtitle)
                        .font(.system(size: 20, weight: .regular))
                        .foregroundColor(.white.opacity(0.6))
                }
                
                // Form fields
                VStack(spacing: 24) {
                    formField(
                        icon: "server.rack",
                        title: String(localized: "Server URL"),
                        placeholder: "",
                        text: $viewModel.serverURL,
                        isSecure: false,
                        keyboardType: .URL,
                        field: .serverURL,
                        nextField: .email
                    )
                    
                    formField(
                        icon: "envelope",
                        title: String(localized: "Email"),
                        placeholder: "your-email@example.com",
                        text: $viewModel.email,
                        isSecure: false,
                        keyboardType: .emailAddress,
                        field: .email,
                        nextField: viewModel.showApiKeyLogin ? .apiKey : .password
                    )
                    
                    if viewModel.showApiKeyLogin {
                        formField(
                            icon: "key",
                            title: String(localized: "API Key"),
                            placeholder: String(localized: "Enter your API key"),
                            text: $viewModel.apiKey,
                            isSecure: true,
                            keyboardType: .default,
                            field: .apiKey,
                            nextField: .signInButton
                        )
                    } else {
                        formField(
                            icon: "lock",
                            title: String(localized: "Password"),
                            placeholder: String(localized: "Enter your password"),
                            text: $viewModel.password,
                            isSecure: true,
                            keyboardType: .default,
                            field: .password,
                            nextField: .signInButton
                        )
                    }
                }
                
                signInButton
                    .padding(.top, 8)
                
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
            
            Text(String(localized: "Make sure your Immich server is accessible from this device"))
                .font(.system(size: 14))
                .foregroundColor(.white.opacity(0.3))
                .padding(.bottom, 40)
        }
        .padding(.horizontal, 80)
        .alert(viewModel.alertTitle, isPresented: $viewModel.showError) {
            Button(String(localized: "OK")) { }
        } message: {
            Text(viewModel.errorMessage)
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
        field: Field,
        nextField: Field?
    ) -> some View {
        let isFocused = focusedField == field
        
        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(isFocused ? brandBlue : brandBlue.opacity(0.7))
                
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(isFocused ? .white : .white.opacity(0.8))
            }
            
            Group {
                if isSecure {
                    SecureField(placeholder, text: text)
                        .onSubmit {
                            focusedField = nextField
                        }
                } else {
                    TextField(placeholder, text: text)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                        .keyboardType(keyboardType)
                        .onSubmit {
                            focusedField = nextField
                        }
                }
            }
            .font(.system(size: 24, weight: .regular))
            .padding(.horizontal, 24)
            .padding(.vertical, 20)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.white.opacity(isFocused ? 0.15 : 0.10))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .strokeBorder(
                                isFocused ? brandBlue.opacity(0.6) : Color.white.opacity(0.15),
                                lineWidth: isFocused ? 2 : 1
                            )
                    )
            )
            .shadow(
                color: isFocused ? brandBlue.opacity(0.3) : Color.clear,
                radius: isFocused ? 12 : 0,
                x: 0,
                y: isFocused ? 4 : 0
            )
            .animation(.easeInOut(duration: 0.2), value: isFocused)
            .focused($focusedField, equals: field)
        }
    }
    
    // MARK: - Sign In Button
    
    private var signInButton: some View {
        Button(action: { viewModel.signIn() }) {
            HStack(spacing: 12) {
                if viewModel.isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.9)
                } else {
                    Image(systemName: viewModel.buttonIcon)
                        .font(.system(size: 20, weight: .semibold))
                }
                
                Text(viewModel.buttonTitle)
                    .font(.system(size: 22, weight: .semibold, design: .rounded))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 22)
            .background(
                LinearGradient(
                    colors: viewModel.canSignIn ? [brandBlue, brandBlue.opacity(0.8)] : [Color.gray.opacity(0.3), Color.gray.opacity(0.2)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .foregroundColor(.white)
            .cornerRadius(16)
            .shadow(color: viewModel.canSignIn ? brandBlue.opacity(0.4) : .clear, radius: 20, x: 0, y: 10)
        }
        .buttonStyle(CardButtonStyle())
        .disabled(!viewModel.canSignIn)
        .focused($focusedField, equals: .signInButton)
    }
    
    // MARK: - API Key Toggle
    
    private var apiKeyToggle: some View {
        Button(action: {
            withAnimation(.easeInOut(duration: 0.3)) {
                viewModel.toggleLoginMode()
            }
        }) {
            HStack(spacing: 8) {
                Image(systemName: viewModel.showApiKeyLogin ? "person.fill" : "key.fill")
                    .font(.system(size: 14))
                
                Text(viewModel.showApiKeyLogin ? String(localized: "Use password instead") : String(localized: "Use API key instead"))
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
}

#Preview {
    let userManager = UserManager()
    let networkService = NetworkService(userManager: userManager)
    let authService = AuthenticationService(networkService: networkService, userManager: userManager)
    SignInView(authService: authService, userManager: userManager, mode: .signIn)
}
