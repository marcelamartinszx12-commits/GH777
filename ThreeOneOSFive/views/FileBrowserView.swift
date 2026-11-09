import SwiftUI

struct FileBrowserView: View {
    @Environment(\.appLanguage) private var language
    let containerPath: String
    let title: String
    @State private var currentPath: String
    @State private var entries: [FileEntry] = []
    @State private var isLoadingEntries = true

    init(containerPath: String, title: String) {
        self.containerPath = containerPath
        self.title = title
        _currentPath = State(initialValue: containerPath)
    }

    var body: some View {
        ZStack {
            Color(red: 0.05, green: 0.05, blue: 0.05).ignoresSafeArea()
            
            VStack {
                if isLoadingEntries {
                    ProgressView().foregroundColor(.purple)
                } else {
                    List {
                        ForEach(entries) { entry in
                            HStack {
                                Image(systemName: entry.isDirectory ? "folder.fill" : "doc.text")
                                    .foregroundColor(entry.isDirectory ? .purple : .white)
                                Text(entry.name).foregroundColor(.white)
                                Spacer()
                                if entry.isDirectory {
                                    Image(systemName: "chevron.right").foregroundColor(.gray)
                                }
                            }
                            .padding(.vertical, 8)
                            .listRowBackground(Color.black)
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                }
            }
        }
        .navigationTitle(title)
        .onAppear { load() }
    }

    private func load() {
        isLoadingEntries = true
        DispatchQueue.global(qos: .userInitiated).async {
            let loaded = ContainerStore.listFiles(at: currentPath)
            DispatchQueue.main.async {
                self.entries = loaded
                self.isLoadingEntries = false
            }
        }
    }
}
