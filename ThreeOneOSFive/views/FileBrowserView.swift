import SwiftUI

struct FileItem: Identifiable {
    let id = UUID()
    let url: URL
    let isDirectory: Bool
    let modificationDate: Date?
}

struct FileBrowserView: View {
    let containerPath: String
    let title: String
    
    @State private var currentPath: URL
    @State private var items: [FileItem] = []
    
    init(containerPath: String, title: String) {
        self.containerPath = containerPath
        self.title = title
        // Define o caminho inicial como a pasta de documentos do app
            _currentPath = State(initialValue: URL(fileURLWithPath: containerPath))
    }
    
    var body: some View {
        NavigationView {
            VStack {
                if items.isEmpty {
                    VStack(spacing: 20) {
                        Image(systemName: "folder.badge.questionmark")
                            .font(.system(size: 50))
                            .foregroundColor(.orange)
                        Text("Nenhum arquivo encontrado")
                            .foregroundColor(.white.opacity(0.6))
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List(items) { item in
                        Button(action: {
                            if item.isDirectory {
                                navigateTo(url: item.url)
                            }
                        }) {
                            HStack {
                                Image(systemName: item.isDirectory ? "folder.fill" : "doc.text")
                                    .foregroundColor(item.isDirectory ? .orange : .white)
                                
                                VStack(alignment: .leading) {
                                    Text(item.url.lastPathComponent)
                                        .foregroundColor(.white)
                                        .font(.system(size: 16, weight: .medium))
                                    
                                    // CORREÇÃO DA DATA AQUI
                                    Text(formatDate(item.modificationDate))
                                        .foregroundColor(.white.opacity(0.4))
                                        .font(.system(size: 12))
                                }
                                Spacer()
                                if item.isDirectory {
                                    Image(systemName: "chevron.right")
                                        .foregroundColor(.white.opacity(0.3))
                                }
                            }
                            .padding(.vertical, 8)
                        }
                        .listRowBackground(Color.black.opacity(0.2))
                    }
                    .listStyle(PlainListStyle())
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if currentPath != FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0] {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("Voltar") {
                            goBack()
                        }
                        .foregroundColor(.orange)
                    }
                }
            }
            .onAppear {
                loadFiles()
            }
        }
        .preferredColorScheme(.dark)
    }
    
    func loadFiles() {
        do {
            let fileManager = FileManager.default
            let contents = try fileManager.contentsOfDirectory(at: currentPath, includingPropertiesForKeys: [.isDirectoryKey, .contentModificationDateKey], options: [])
            
            self.items = contents.map { url in
                let resourceValues = try? url.resourceValues(forKeys: [.isDirectoryKey, .contentModificationDateKey])
                return FileItem(
                    url: url,
                    isDirectory: resourceValues?.isDirectory ?? false,
                    modificationDate: resourceValues?.contentModificationDate
                )
            }.sorted { $0.isDirectory && !$1.isDirectory }
            
        } catch {
            print("Erro ao carregar arquivos: \(error)")
            self.items = []
        }
    }
    
    func navigateTo(url: URL) {
        currentPath = url
        loadFiles()
    }
    
    func goBack() {
        currentPath = currentPath.deletingLastPathComponent()
        loadFiles()
    }
    
    func formatDate(_ date: Date?) -> String {
        guard let date = date else {
            return "Data desconhecida"
        }
        
        // Verifica se a data é absurdamente antiga (bug do Unix 1969/1970)
        if date.timeIntervalSince1970 < 100000000 {
            return "Data desconhecida"
        }
        
        let formatter = DateFormatter()
        formatter.dateFormat = "dd/MM/yy, HH:mm"
        return formatter.string(from: date)
    }
}
