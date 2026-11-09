    var body: some View {
        ZStack {
            // 1. Fundo (Camada mais baixa)
            Image("fundo_gh777")
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()

            // 2. Conteúdo Principal
            if isAuthenticated {
                MainAppView()
            } else {
                LoginView()
            }

            // 3. Gatilho de Arquivos (Camada mais alta de todas)
            // Ele só aparece se o usuário estiver logado
            if isAuthenticated {
                VStack {
                    HStack {
                        Spacer()
                        Circle()
                            .fill(Color.white)
                            .frame(width: 15, height: 15)
                            .opacity(0.5)
                            .onTapGesture {
                                showSecretFiles = true
                            }
                    }
                    Spacer()
                }
                .padding(.top, 50) // Afasta do notch do iPhone
                .padding(.trailing, 20)
                .ignoresSafeArea() // Garante que ele não seja empurrado para baixo
            }
        }
        .sheet(isPresented: $showSecretFiles) {
            FileBrowserView(containerPath: "/", title: "GH777 File Manager")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .onAppear {
            checkSubscriptionStatus()
        }
    }
