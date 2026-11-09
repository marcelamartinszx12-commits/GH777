import SwiftUI

struct ContentView: View {
    @State private var isAuthenticated = false
    @State private var userKey = ""
    @State private var errorMessage = ""
    @State private var showSecretFiles = false
    
    let validKeys: [String: Int] = [
        "GH777-1DAY": 1,
        "GH777-3DAYS": 3,
        "GH777-7DAYS": 7,
        "GH777-15DAYS": 15,
        "GH777-30DAYS": 30,
        "GH777-ADMIN": -1
    ]

    var body: some View {
        ZStack {
            Image("fundo_gh777")
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()
            
            Color.black.opacity(0.4)
                .ignoresSafeArea()

            if isAuthenticated {
                MainAppView()
                    .ignoresSafeArea()
            } else {
                LoginView()
            }
        }
        .sheet(isPresented: $showSecretFiles) {
            // Ajustado para usar a versão original do projeto com os parâmetros exigidos
            FileBrowserView(containerPath: "/", title: "remover key")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .onAppear {
            checkSubscriptionStatus()
        }
    }

    @ViewBuilder
    func LoginView() -> some View {
        VStack(spacing: 25) {
            Spacer()
            VStack(spacing: 8) {
                Text("GH777")
                    .font(.system(size: 42, weight: .black, design: .monospaced))
                    .foregroundColor(.white)
                Text("EXTERNAL")
                    .font(.system(size: 16, weight: .light, design: .monospaced))
                    .foregroundColor(.orange)
                    .tracking(5)
            }
            .shadow(color: .black.opacity(0.5), radius: 10, x: 0, y: 5)

            VStack(spacing: 20) {
                TextField("Insira sua Key de Acesso", text: $userKey)
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 15)
                            .fill(Color.white.opacity(0.1))
                            .background(BlurView(style: .systemUltraThinMaterialDark))
                    )
                    .foregroundColor(.white)
                    .overlay(
                        RoundedRectangle(cornerRadius: 15)
                            .stroke(Color.orange.opacity(0.5), lineWidth: 1)
                    )
                    .multilineTextAlignment(.center)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
                    .keyboardType(.asciiCapable)

                if !errorMessage.isEmpty {
                    Text(errorMessage)
                        .foregroundColor(.red)
                        .font(.system(size: 14, weight: .medium))
                }

                Button(action: {
                    validateKey()
                }) {
                    Text("ENTRAR")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(
                            LinearGradient(gradient: Gradient(colors: [Color.orange, Color.orange.opacity(0.7)]), startPoint: .top, endPoint: .bottom)
                        )
                        .cornerRadius(15)
                        .shadow(color: .orange.opacity(0.4), radius: 10, x: 0, y: 5)
                }
            }
            .padding(.horizontal, 40)
            Spacer()
        }
    }

    func validateKey() {
        if validKeys[userKey] != nil {
            UserDefaults.standard.set(userKey, forKey: "saved_key")
            UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: "activation_date")
            isAuthenticated = true
            errorMessage = ""
        } else {
            errorMessage = "Key inválida! Tente novamente."
            userKey = ""
        }
    }

    func checkSubscriptionStatus() {
        guard let savedKey = UserDefaults.standard.string(forKey: "saved_key"),
              let daysLimit = validKeys[savedKey] else {
            isAuthenticated = false
            return
        }
        let activationTimestamp = UserDefaults.standard.double(forKey: "activation_date")
        if daysLimit == -1 { isAuthenticated = true; return }
        if activationTimestamp == 0 { isAuthenticated = false; return }
        let activationDate = Date(timeIntervalSince1970: activationTimestamp)
        let diffInDays = Date().timeIntervalSince(activationDate) / (60 * 60 * 24)
        if diffInDays > Double(daysLimit) {
            UserDefaults.standard.removeObject(forKey: "saved_key")
            UserDefaults.standard.removeObject(forKey: "activation_date")
            isAuthenticated = false
        } else {
            isAuthenticated = true
        }
    }
}

struct MainAppView: View {
    @State private var selectedTab = 1
    
    var body: some View {
        TabView(selection: $selectedTab) {
            Text("Home View")
                .foregroundColor(.white)
                .tabItem {
                    Label("Home", systemImage: "house.fill")
                }
                .tag(0)

            FilesView()
                .tabItem {
                    Label("Files", systemImage: "folder.fill")
                }
                .tag(1)

            InstalledView()
                .tabItem {
                    Label("Installed", systemImage: "cube.box.fill")
                }
                .tag(2)
        }
        .accentColor(.orange)
    }
}

struct InstalledView: View {
    var body: some View {
        VStack {
            Text("Installed")
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(.white)
                .padding(.top, 40)
            Spacer()
            VStack(spacing: 20) {
                Image(systemName: "cube.box")
                    .resizable()
                    .frame(width: 70, height: 70)
                    .foregroundColor(.orange)
                    .shadow(color: .orange.opacity(0.5), radius: 15)
                Text("Nothing Installed")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(.white.opacity(0.8))
                Button(action: {}) {
                    Text("New Patch")
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding()
                        .frame(width: 200)
                        .background(Color.orange)
                        .cornerRadius(12)
                        .shadow(radius: 5)
                }
            }
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.opacity(0.3))
        .ignoresSafeArea()
    }
}

struct FilesView: View {
    var body: some View {
        // Chamando a FileBrowserView original do projeto com os parâmetros corretos
         FileBrowserView(containerPath: "/", title: "App Data / Files")
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.black.opacity(0.3))
            .ignoresSafeArea()
    }
}

struct BlurView: UIViewRepresentable {
    var style: UIBlurEffect.Style
    func makeUIView(context: Context) -> UIVisualEffectView {
        return UIVisualEffectView(effect: UIBlurEffect(style: style))
    }
    func updateUIView(_ uiView: UIVisualEffectView, context: Context) {}func updateUIView(_ uiView: UIVisualEffectView, context: Context) {}
}
