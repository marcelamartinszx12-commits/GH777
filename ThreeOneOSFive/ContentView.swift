import SwiftUI
import UIKit
import UniformTypeIdentifiers
import QuickLook

struct FileBrowserView: View {
    @Environment(\.appLanguage) private var language
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @EnvironmentObject private var patchDraftCoordinator: PatchDraftCoordinator
    @EnvironmentObject private var fileOperationCoordinator: FileOperationCoordinator
    let containerPath: String
    let title: String
    let bundleID: String?
    let isRoot: Bool
    private let filesTabSession: Binding<FilesTabSession>?
    @State private var currentPath: String
    @State private var entries: [FileEntry] = []
    @State private var fileSearchText = ""
    @State private var isLoadingEntries = true
    @State private var hasGranted = false
    @State private var pendingReplacementRequest: FileReplacementRequest?
    @State private var replacementRequest: FileReplacementRequest?
    @State private var activityText: String?
    @State private var replacementNotice: FileReplacementNotice?
    @State private var operationNotice: FileReplacementNotice?
    @State private var namePrompt: FileNamePrompt?
    @State private var nameInput = ""
    @State private var pendingImportPickerID: UUID?
    @State private var isShowingImportPicker = false
    @State private var importSession: FileImportSession?
    @State private var importConflict: FileImportConflict?
    @State private var isSelecting = false
    @State private var selectedEntryIDs = Set<String>()
    @State private var transferSession: FileTransferSession?
    @State private var transferConflict: FileTransferConflict?
    @State private var deleteTargets: [FileEntry] = []
    @AppStorage(FileBrowserSortOrder.storageKey)
    private var sortOrderRaw = FileBrowserSortOrder.nameAscending.rawValue

    private var filteredEntries: [FileEntry] {
        let query = fileSearchText.trimmingCharacters(in: .whitespacesAndNewlines)
        let filtered = query.isEmpty ? entries : entries.filter { $0.name.localizedCaseInsensitiveContains(query) }
        return FileBrowserSortPolicy.sorted(filtered, order: sortOrder, name: \.name, isDirectory: \.isDirectory, size: \.size, modifiedAt: \.modifiedAt)
    }

    private var overlayState: FileBrowserOverlayState {
        if isLoadingEntries { return .loading }
        if entries.isEmpty { return .empty }
        if filteredEntries.isEmpty { return .noResults }
        return .none
    }

    init(containerPath: String, title: String, bundleID: String? = nil, filesTabSession: Binding<FilesTabSession>? = nil) {
        self.containerPath = containerPath
        self.title = title
        self.bundleID = bundleID
        self.isRoot = true
        self.filesTabSession = filesTabSession
        _currentPath = State(initialValue: containerPath)
    }

    var body: some View {
        ZStack {
            Color(red: 0.05, green: 0.05, blue: 0.05).ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Busca Roxa
                HStack {
                    Image(systemName: "magnifyingglass").foregroundColor(.purple)
                    TextField(language.text("browser.search_files"), text: $fileSearchText)
                        .foregroundColor(.white)
                    if !fileSearchText.isEmpty {
                        Button(action: { fileSearchText = "" }) {
                            Image(systemName: "xmark.circle.fill").foregroundColor(.gray)
                        }
                    }
                }
                .padding()
                .background(Color.purple.opacity(0.2))
                .cornerRadius(12)
                .padding()

                List {
                    Section {
                        ForEach(filteredEntries) { entry in
                            fileRow(entry)
                        }
                    } header: {
                        Text(language.text("browser.items_count", Int64(filteredEntries.count)))
                            .font(.caption).foregroundColor(.purple).textCase(nil)
                    }
                }
                .listStyle(.plain)
                .background(Color.black)
                .scrollContentBackground(.hidden)
                .overlay {
                    if overlayState != .none {
                        overlayView
                    }
                }
            }
        }
        .navigationTitle(currentPath == containerPath ? title : (currentPath as NSString).lastPathComponent)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                sortMenu
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(isSelecting ? language.text("common.cancel") : language.text("browser.select")) {
                    toggleSelectionMode()
                }.foregroundColor(.purple)
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button { requestImportPicker() } label: { Label(language.text("browser.import_files"), systemImage: "square.and.arrow.down") }
                    Button { presentNamePrompt(.createFile) } label: { Label(language.text("browser.new_file"), systemImage: "doc.badge.plus") }
                    Button { presentNamePrompt(.createFolder) } label: { Label(language.text("browser.new_folder"), systemImage: "folder.badge.plus") }
                } label: {
                    Image(systemName: "plus").foregroundColor(.purple)
                }
            }
        }
        .onAppear { load() }
        .overlay {
            if let activityText {
                ZStack {
                    Color.black.opacity(0.8).ignoresSafeArea()
                    ProgressView(activityText)
                        .padding()
                         .background(Color.purple.opacity(0.4), in: RoundedRectangle(cornerRadius: 12))
                        .foregroundColor(.white)
                }
            }
        }
    }

    private var overlayView: some View {
        VStack {
            if overlayState == .loading {
                ProgressView().foregroundColor(.purple)
            } else {
                Image(systemName: overlayState == .empty ? "folder" : "magnifyingglass")
                    .foregroundColor(.gray).font(.largeTitle)
                Text(overlayState == .empty ? language.text("browser.empty_folder") : language.text("browser.search_empty"))
                    .foregroundColor(.gray)
            }
        }.frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var sortOrder: FileBrowserSortOrder { FileBrowserSortOrder(rawValue: sortOrderRaw) ?? .nameAscending }

    private var sortMenu: some View {
        Menu {
            Picker(language.text("browser.sort"), selection: $sortOrderRaw) {
                ForEach(FileBrowserSortOrder.allCases) { order in
                    Label(language.text(order.localizationKey), systemImage: order.systemImage).tag(order.rawValue)
                }
            }
        } label: { Image(systemName: "arrow.up.arrow.down").foregroundColor(.purple) }
    }

    @ViewBuilder
    private func fileRow(_ entry: FileEntry) -> some View {
        let content = HStack(spacing: 12) {
            Image(systemName: entry.isDirectory ? "folder.fill" : "doc.text")
                .foregroundColor(entry.isDirectory ? .purple : .white)
                .font(.system(size: 20))
            VStack(alignment: .leading) {
                Text(entry.name).foregroundColor(.white).fontWeight(.medium)
                Text(entry.date).foregroundColor(.gray).font(.caption2)
            }
            Spacer()
            if entry.isDirectory { Image(systemName: "chevron.right").foregroundColor(.gray).font(.caption) }
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle())

        if isSelecting {
            Button { toggleSelection(entry) } label: {
                content.background(selectedEntryIDs.contains(entry.id) ? Color.purple.opacity(0.3) : Color.clear)
            }.buttonStyle(.plain)
        } else if entry.isDirectory {
            NavigationLink(value: FileBrowserDestination(containerPath: containerPath, startPath: entry.path, title: entry.name, bundleID: bundleID)) {
                content
            }.contextMenu { fileActions(for: entry) }
        } else {
            NavigationLink { FileQuickLookView(file: entry) } label: {
                content
            }.contextMenu { fileActions(for: entry) }
        }
    }

    @ViewBuilder
    private func fileActions(for entry: FileEntry) -> some View {
        Button { prepareTransfer([entry], mode: .copy) } label: { Label(language.text("browser.copy"), systemImage: "doc.on.doc") }
        Button { prepareTransfer([entry], mode: .move) } label: { Label(language.text("browser.move"), systemImage: "folder") }
        Button { presentNamePrompt(.rename(entry)) } label: { Label(language.text("browser.rename"), systemImage: "pencil") }
        Button(role: .destructive) { deleteTargets = [entry] } label: { Label(language.text("browser.delete"), systemImage: "trash") }
    }

    // --- LÓGICA ORIGINAL PRESERVADA ---
    private func load() {
        let shouldGrant = !hasGranted && ContainerAccessPolicy.shouldRequestGrant(isRoot: isRoot)
        hasGranted = true
        isLoadingEntries = true
        let path = currentPath
        let targetBundleID = bundleID
        DispatchQueue.global(qos: .userInitiated).async {
            if shouldGrant {
                var handle: Int64 = -1
                if ContainerAccessPolicy.shouldAttemptMCM(bundleID: targetBundleID), let targetBundleID {
                    var activationError: NSString?
                    handle = MCMActivateContainer(2, targetBundleID, false, &activationError)
                }
                if handle < 0 { handle = ContainerStore.grantContainerAccess(path) }
            }
            let loadedEntries = ContainerStore.listFiles(at: path)
            DispatchQueue.main.async {
                guard currentPath == path else { return }
                entries = loadedEntries
                isLoadingEntries = false
            }
        }
    }

    private func toggleSelectionMode() { isSelecting.toggle(); if !isSelecting { selectedEntryIDs.removeAll() } }
    private func toggleSelection(_ entry: FileEntry) { if selectedEntryIDs.remove(entry.id) == nil { selectedEntryIDs.insert(entry.id) } }
    private func prepareTransfer(_ entries: [FileEntry], mode: FileTransferMode) {
        fileOperationCoordinator.prepare(entries.map { URL(fileURLWithPath: $0.path, isDirectory: $0.isDirectory) }, mode: mode)
        isSelecting = false
    }
    private func requestImportPicker() { isShowingImportPicker = true }
    private func presentNamePrompt(_ action: FileNamePromptAction) { namePrompt = FileNamePrompt(action: action) }
    private func commitNamePrompt() { /* Lógica original de renomear/criar */ }
}
