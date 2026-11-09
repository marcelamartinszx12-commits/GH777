import SwiftUI

struct ContentView: View {
    @Environment(\.appLanguage) private var language
    @State private var isAuthenticated = false
    @State private var licenseKey = ""
    @State private var showingLoginError = false

    var body: some View {
        ZStack {
            Color(red: 0.05, green: 0.05, blue: 0.05).ignoresSafeArea()
            
            if isAuthenticated {
                TabView {
                    // Aba Principal / Home
                    NavigationStack {
                        VStack {
                            Image(systemName: "shield.fill")
                                .font(.system(size: 80))
                                .foregroundColor(.purple)
                                .padding(.bottom, 20)
                            
                            Text("GH777 EXTERNAL")
                                .font(.title).bold()
                                .foregroundColor(.white)
                            
                            Text(language.text("welcome_message"))
                                .foregroundColor(.gray)
                                .padding(.top, 10)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .navigationTitle("Dashboard")
                    }
                    .tabItem {
                        Label("Home", systemImage: "house.fill")
                    }

                    // Aba de Arquivos (Onde entra a FileBrowserView)
                    NavigationStack {
                        FileBrowserView(containerPath: "/var/mobile/Containers/Data/Application/", title: "Files")
                            .navigationTitle("File Browser")
                    }
                    .tabItem {
                        Label("Files", systemImage: "folder.fill")
                    }

                    // Aba de Configurações
                    NavigationStack {
                        SettingsView()
                            .navigationTitle("Settings")
                    }
                    .tabItem {
                        Label("Settings", systemImage: "gearshape.fill")
                    }
                }
                .accentColor(.purple)
            } else {
                // Tela de Login
                VStack(spacing: 25) {
                    VStack(spacing: 10) {
                        Text("GH777")
                            .font(.system(size: 40, weight: .black, design: .rounded))
                            .foregroundColor(.purple)
                        
                        Text("EXTERNAL ACCESS")
                            .font(.caption)
                            .foregroundColor(.gray)
                            .tracking(4)
                    }
                    .padding(.bottom, 40)

                    TextField("Enter License Key", text: $licenseKey)
                        .padding()
                        .background(Color.purple.opacity(0.1))
                        .foregroundColor(.white)
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.purple.opacity(0.5), lineWidth: 1)
                        )
                        .textFieldStyle(PlainTextFieldStyle())
                        .multilineTextAlignment(.center)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)

                    Button(action: validateLicense) {
                        Text("ACTIVATE")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.purple)
                            .cornerRadius(12)
                            .shadow(color: .purple.opacity(0.4), radius: 10, x: 0, y: 5)
                    }
                }
                .padding(30)
            }
        }
        .alert("Invalid Key", isPresented: $showingLoginError) {
            Button("Try Again", role: .cancel) { }
        } message: {
            Text("The license key provided is incorrect or expired.")
        }
    }

    private func validateLicense() {
        // Lógica simplificada de validação para o build
        if !licenseKey.isEmpty {
            isAuthenticated = true
        } else {
            showingLoginError = true
        }
    }
}
