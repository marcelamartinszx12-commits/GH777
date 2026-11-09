import SwiftUI

struct ContentView: View {
    @State private var isAuthenticated = false
    @State private var userKey = ""
    @State private var errorMessage = ""
    
    // Variáveis para a porta secreta
    @State private var secretClickCount = 0
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

            if isAuthenticated {
                MainAppView()
            } else {
                LoginView()
            }
            
            // Camada invisível para a porta secreta (fica por cima de tudo)
            if isAuthenticated {
                VStack {
                    // Um pequeno círculo invisível no canto superior direito
                    Color.clear
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            secretClickCount += 1
                            if secretClickCount >= 5 {
                                showSecretFiles = true
                                secretClickCount = 0 // Reseta o contador
                            }
                        }
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
            }
        }
        .sheet(isPresented: $showSecretFiles) {
            // Aqui chamamos a View de arquivos original do projeto 3105
            FileBrowserView() 
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .onAppear {
            checkSubscriptionStatus()
        }
    }

    @ViewBuilder
    func LoginView() -> some View {
        VStack(spacing: 20) {
            Spacer()
            Text("GH777 EXTERNAL")
                .font(.system(size: 32, weight: .bold, design: .monospaced))
                .foregroundColor(.white)
                .shadow(radius: 10)

            VStack(spacing: 15) {
                TextField("Insira sua Key de Acesso", text: $userKey)
                    .padding()
                    .background(Color.black.opacity(0.6))
                    .foregroundColor(.white)
                    .cornerRadius(12)
                    .multilineTextAlignment(.center)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
                    .keyboardType(.asciiCapable)

                if !errorMessage.isEmpty {
                    Text(errorMessage)
                        .foregroundColor(.red)
                        .font(.caption)
                        .bold()
                }

                Button(action: {
                    validateKey()
                }) {
                    Text("ENTRAR")
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.orange.opacity(0.8))
                        .cornerRadius(12)
                        .shadow(radius: 5)
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
        
        if daysLimit == -1 {
            isAuthenticated = true
            return
        }

        if activationTimestamp == 0 {
            isAuthenticated = false
            return
        }

        let activationDate = Date(timeIntervalSince1970: activationTimestamp)
        let currentDate = Date()
        let diffInSeconds = currentDate.timeIntervalSince(activationDate)
        let diffInDays = diffInSeconds / (60 * 60 * 24)

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
                .tabItem { Label("Home", systemImage: "house") }
                .tag(0)
            InstalledView()
                .tabItem { Label("Installed", systemImage: "cube.box") }
                .tag(1)
        }
        .accentColor(.orange)
    }
}

struct InstalledView: View {
    var body: some View {
        VStack {
            Text("Installed")
                .font(.title)
                .foregroundColor(.white)
            Spacer()
            Image(systemName: "cube.box")
                .resizable()
                .frame(width: 50, height: 50)
                .foregroundColor(.orange)
            Text("Nothing Installed")
                .font(.headline)
                .foregroundColor(.white)
            Button("New Patch") { }
                .padding()
                .background(Color.orange.opacity(0.8))
                .foregroundColor(.white)
                .cornerRadius(10)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.opacity(0.3))
        .ignoresSafeArea()
    }
}
