import SwiftUI

struct AccountSettingsView: View {
    @ObservedObject var authService: AuthenticationService
    @ObservedObject var userManager: UserManager
    @State private var showingDeleteUserAlert = false
    @State private var userToDelete: SavedUser?
    @State private var showingSignIn = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 30) {
                // Server Info Section
                serverInfoSection
                
                // User Management Section
                userActionsSection
            }
            .padding(.horizontal, 40)
            .padding(.vertical, 20)
        }
        .fullScreenCover(isPresented: $showingSignIn) {
            SignInView(authService: authService, userManager: userManager, mode: .addUser, onUserAdded: { userManager.loadUsers() })
        }
        .alert(String(localized: "Delete User"), isPresented: $showingDeleteUserAlert) {
            Button(String(localized: "Cancel"), role: .cancel) {
                userToDelete = nil
            }
            Button(String(localized: "Delete"), role: .destructive) {
                if let user = userToDelete {
                    removeUser(user)
                }
                userToDelete = nil
            }
        } message: {
            if let user = userToDelete {
                let isCurrentUser = userManager.currentUser?.id == user.id
                let isLastUser = userManager.savedUsers.count == 1
                
                if isCurrentUser && isLastUser {
                    Text(LocalizedStringResource("Are you sure you want to delete this user? This will sign you out and you'll need to sign in again to access your photos."))
                } else if isCurrentUser {
                    Text(LocalizedStringResource("Are you sure you want to delete the current user? You will be switched to another saved user."))
                } else {
                    Text(LocalizedStringResource("Are you sure you want to delete this user account?"))
                }
            } else {
                Text(LocalizedStringResource("Are you sure you want to delete this user?"))
            }
        }
        .onAppear {
            userManager.loadUsers()
        }
    }
    
    private var serverInfoSection: some View {
        Button(action: {
            refreshServerConnection()
        }) {
            HStack(spacing: 20) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    authService.baseURL.lowercased().hasPrefix("https") ? Color.green.opacity(0.2) : Color.red.opacity(0.2),
                                    authService.baseURL.lowercased().hasPrefix("https") ? Color.green.opacity(0.1) : Color.red.opacity(0.1)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 100, height: 100)
                    
                    Image(systemName: authService.baseURL.lowercased().hasPrefix("https") ? "lock.fill" : "lock.open.fill")
                        .foregroundColor(authService.baseURL.lowercased().hasPrefix("https") ? .green : .red)
                        .font(.system(size: 40, weight: .semibold))
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text(LocalizedStringResource("Server Connection"))
                        .font(.system(size: 32, weight: .semibold))
                        .foregroundColor(.primary)
                    
                    Text(authService.baseURL)
                        .font(.system(size: 24))
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
                
                Spacer()
                
                VStack(spacing: 12) {
                    HStack(spacing: 12) {
                        Image(systemName: "arrow.clockwise")
                            .foregroundColor(.blue)
                            .font(.system(size: 28))
                        Text(LocalizedStringResource("Refresh"))
                            .font(.system(size: 24))
                            .foregroundColor(.blue)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(
                        Capsule()
                            .fill(Color.blue.opacity(0.15))
                    )
                    
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .font(.system(size: 32))
                }
            }
            .padding(24)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(
                        LinearGradient(
                            colors: [Color.green.opacity(0.1), Color.green.opacity(0.05)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.green.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(CardButtonStyle())
    }
    
    private var userActionsSection: some View {
        VStack(spacing: 16) {
            if userManager.savedUsers.count > 0 {
                ForEach(userManager.savedUsers, id: \.id) { user in
                    userRow(user: user)
                }
            }
            
            Button(action: {
                showingSignIn = true
            }) {
                HStack(spacing: 16) {
                    Image(systemName: "person.badge.plus")
                        .font(.system(size: 32))
                        .foregroundColor(.blue)
                    Text(LocalizedStringResource("Add User"))
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundColor(.primary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(
                            LinearGradient(
                                colors: [Color.blue.opacity(0.15), Color.blue.opacity(0.08)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Color.blue.opacity(0.3), lineWidth: 1)
                )
            }
            .buttonStyle(CardButtonStyle())
        }
    }
    
    private func userRow(user: SavedUser) -> some View {
        HStack {
            Button(action: {
                switchToUser(user)
            }) {
                HStack {
                    HStack(spacing: 16) {
                        ProfileImageView(
                            userId: user.id,
                            authType: user.authType,
                            size: 100,
                            profileImageData: user.profileImageData
                        )
                        
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 8) {
                                Badge(
                                    user.authType == .apiKey ? "API Key" : "Password",
                                    color: user.authType == .apiKey ? Color.orange : Color.blue
                                )
                                
                                Text(user.name)
                                    .font(.system(size: 28, weight: .semibold))
                                    .foregroundColor(.primary)
                            }
                            
                            Text(user.email)
                                .font(.system(size: 24))
                                .foregroundColor(.secondary)
                            
                            Text(user.serverURL)
                                .font(.system(size: 20))
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }
                    }
                    
                    Spacer()
                    
                    if userManager.currentUser?.id == user.id {
                        Badge("Active", color: Color.green)
                    } else {
                        Image(systemName: "arrow.right.circle")
                            .foregroundColor(user.authType == .apiKey ? .orange : .blue)
                            .font(.title3)
                    }

                }
                .padding()
                .background {
                    let accentColor = user.authType == .apiKey ? Color.orange : Color.blue
                    RoundedRectangle(cornerRadius: 12)
                        .fill(accentColor.opacity(0.05))
                }
            }
            .buttonStyle(CardButtonStyle())
            
            Button(action: {
                userToDelete = user
                showingDeleteUserAlert = true
            }) {
                Image(systemName: "trash")
                    .foregroundColor(.red)
                    .font(.system(size: 32))
                    .padding(12)
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(10)
            }
            .buttonStyle(CardButtonStyle())
        }
    }
    
    private func switchToUser(_ user: SavedUser) {
        Task {
            do {
                try await authService.switchUser(user)
                
                await MainActor.run {
                    NotificationCenter.default.post(name: NSNotification.Name(NotificationNames.refreshAllTabs), object: nil)
                }
                
            } catch {
                debugLog("AccountSettingsView: Failed to switch user: \(error)")
            }
        }
    }
    
    private func removeUser(_ user: SavedUser) {
        Task {
            do {
                let wasCurrentUser = userManager.currentUser?.id == user.id
                
                try await userManager.removeUser(user)
                
                if wasCurrentUser {
                    if userManager.hasCurrentUser {
                        debugLog("AccountSettingsView: Switching to next available user after removal")
                        authService.updateCredentialsFromCurrentUser()
                        
                        await MainActor.run {
                            authService.isAuthenticated = true
                        }
                        
                        try await authService.fetchUserInfo()
                        NotificationCenter.default.post(name: NSNotification.Name(NotificationNames.refreshAllTabs), object: nil)
                    } else {
                        debugLog("AccountSettingsView: No users left, signing out completely")
                        await MainActor.run {
                            authService.isAuthenticated = false
                            authService.currentUser = nil
                        }
                        authService.clearCredentials()
                    }
                }
            } catch {
                debugLog("AccountSettingsView: Failed to remove user: \(error)")
            }
        }
    }
    
    private func refreshServerConnection() {
        Task {
            do {
                try await authService.fetchUserInfo()
                debugLog("✅ Server connection refreshed successfully")
                
                DispatchQueue.main.async {
                    NotificationCenter.default.post(name: NSNotification.Name(NotificationNames.refreshAllTabs), object: nil)
                }
            } catch {
                debugLog("❌ Failed to refresh server connection: \(error)")
            }
        }
    }
}

