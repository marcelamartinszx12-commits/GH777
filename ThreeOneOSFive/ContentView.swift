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
            // 1. Fundo
            Image("fundo_gh777")
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()

            // 2. Conteúdo
            if isAuthenticated {
                // Aqui chamamos a MainAppView que agora tem as 3 abas
                MainAppView()
                    .ignoresSafeArea()
            } else {
                LoginView()
            }
        }
        .sheet(isPresented: $showSecretFiles) {
            FileBrowserView(containerPath: "/", title: "remover key")
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

// --- AQUI ESTÁ A MUDANÇA PRINCIPAL ---
struct MainAppView: View {
    @State private var selectedTab = 1
    
    var body: some View {
        TabView(selection: $selectedTab) {
            // Aba 1: Home
            Text("Home View")
                .foregroundColor(.white)
                .tabItem {
                    Label("Home", systemImage: "house")
                }
                .tag(0)

            // Aba 2: Resetar Key (A pasta Files que você pediu)
            FilesView()
                .tabItem {
                    Label("Resetar Key", systemImage: "folder")
                }
                .tag(1)

            // Aba 3: Installed
            InstalledView()
                .tabItem {
                    Label("Installed", systemImage: "cube.box")
                }
                .tag(2)
        }
        .accentColor(.orange)
    }
}

struct InstalledView: View {
    var body: some View {
        VStack {
            Text("Installed").font(.title).foregroundColor(.white)
            Spacer()
            Image(systemName: "cube.box").resizable().frame(width: 50, height: 50).foregroundColor(.orange)
            Text("Nothing Installed").font(.headline).foregroundColor(.white)
            Button("New Patch") { }.padding().background(Color.orange.opacity(0.8)).foregroundColor(.white).cornerRadius(10)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.opacity(0.3))
        .ignoresSafeArea()
    }
}

struct FilesView: View {
    var body: some View {
        FileBrowserView()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.black.opacity(0.3))
            .ignoresSafeArea()
    }
}

struct FileBrowserView: View {
    @State private var currentPath: String = "/"
    @State private var items: [URL] = []

    var body: some View {
        VStack {
            HStack {
                if currentPath != "/" {
                    Button(action: { goBack() }) {
                        Image(systemName: "chevron.left")
                            .foregroundColor(.orange)
                            .padding()
                    }
                }
                Text(currentPath)
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.leading, 20)
                Spacer()
            }
            .padding(.top, 50)
            .background(Color.black.opacity(0.5))

            List(items, id: \.self) {
                item in
                HStack {
                    Image(systemName: item.hasDirectoryPath ? "folder" : "doc")
                        .foregroundColor(.orange)
                    Text(item.lastPathComponent)
                        .foregroundColor(.white)
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    if item.hasDirectoryPath {
                        navigateTo(item.path)
                    }
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(Color.clear)
        }
        .onAppear { loadFiles() }
    }

    func loadFiles() {
        let fileManager = FileManager.default
        do {
            let urls = try fileManager.contentsOfDirectory(atPath: currentPath)
            items = urls.map { URL(fileURLWithPath: (currentPath as NSString).appendingPathComponent($0)) }
            // Ordenar pastas primeiro
            items.sort { $0.hasDirectoryPath && !$1.hasDirectoryPath }
        } catch {
            print("Erro ao carregar arquivos: \(error)")
        }
    }

    func navigateTo(_ path: String) {
        currentPath = path
        loadFiles()
    }

    func goBack() {
        let url = URL(fileURLWithPath: currentPath)
        currentPath = url.deletingLastPathComponent().path
        if currentPath.isEmpty { currentPath = "/" }
        loadFiles()
    }
}
