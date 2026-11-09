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
        let filtered = query.isEmpty
            ? entries
            : entries.filter { $0.name.localizedCaseInsensitiveContains(query) }
        return FileBrowserSortPolicy.sorted(
            filtered,
            order: sortOrder,
            name: \.name,
            isDirectory: \.isDirectory,
            size: \.size,
            modifiedAt: \.modifiedAt
        )
    }

    private var selectedEntries: [FileEntry] {
        entries.filter { selectedEntryIDs.contains($0.id) }
    }

    private var overlayState: FileBrowserOverlayState {
        if isLoadingEntries { return .loading }
        if entries.isEmpty { return .empty }
        if filteredEntries.isEmpty { return .noResults }
        return .none
    }

    private var interfaceAnimation: Animation? {
        reduceMotion ? nil : .easeOut(duration: 0.20)
    }

    init(
        containerPath: String,
        title: String,
        bundleID: String? = nil,
        filesTabSession: Binding<FilesTabSession>? = nil
    ) {
        self.containerPath = containerPath
        self.title = title
        self.bundleID = bundleID
        self.isRoot = true
        self.filesTabSession = filesTabSession
        _currentPath = State(initialValue: containerPath)
    }

    var body: some View {
        ZStack {
            // Fundo GH777
            Color.black.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Campo de busca estilizado
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.orange)
                    TextField(language.text("browser.search_files"), text: $fileSearchText)
                        .foregroundColor(.white)
                    if !fileSearchText.isEmpty {
                        Button(action: { fileSearchText = "" }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.gray)
                        }
                    }
                }
                .padding()
                .background(Color.white.opacity(0.1))
                .cornerRadius(12)
                .padding()

                Divider().background(Color.orange.opacity(0.5))

                List {
                    Section {
                        ForEach(filteredEntries) { entry in
                            fileRow(entry)
                        }
                    } header: {
                        Text(language.text("browser.items_count", Int64(filteredEntries.count)))
                            .font(.caption)
                            .foregroundColor(.orange)
                            .textCase(nil)
                    }
                }
                .listStyle(.insetGrouped)
                .scrollDismissesKeyboard(.interactively)
                .background(Color.black)
                .overlay {
                    Group {
                        switch overlayState {
                        case .loading:
                            ProgressView(language.text("browser.loading")).foregroundColor(.orange)
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                        case .empty:
                            fileEmptyView
                        case .noResults:
                            searchEmptyView
                        case .none:
                            EmptyView()
                        }
                    }
                    .foregroundColor(.white)
                    .transition(.opacity)
                    .animation(interfaceAnimation, value: overlayState)
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
                }
                .foregroundColor(.orange)
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    if let payload = fileOperationCoordinator.payload {
                        Button { beginPaste(payload) } label: {
                            Label(language.text("browser.paste_count", Int64(payload.itemCount)), systemImage: "doc.on.clipboard")
                        }
                    }
                    Button { requestImportPicker() } label: {
                        Label(language.text("browser.import_files"), systemImage: "square.and.arrow.down")
                    }
                    Button { presentNamePrompt(.createFile) } label: {
                        Label(language.text("browser.new_file"), systemImage: "doc.badge.plus")
                    }
                    Button { presentNamePrompt(.createFolder) } label: {
                        Label(language.text("browser.new_folder"), systemImage: "folder.badge.plus")
                    }
                } label: {
                    Image(systemName: "plus").foregroundColor(.orange)
                }
            }
        }
        .onAppear { load() }
        // Mantendo todos os Sheets e Alerts originais para não quebrar a lógica
        .sheet(item: $replacementRequest) { request in
            FileDocumentPicker(allowsMultipleSelection: false, onSelection: { result in
                handleReplacementImport(result, request: request)
                replacementRequest = nil
            }, onCancel: { replacementRequest = nil })
        }
        .sheet(isPresented: $isShowingImportPicker) {
            FileDocumentPicker(allowsMultipleSelection: true, onSelection: { result in
                isShowingImportPicker = false
                handleImportPickerResult(result)
            }, onCancel: { isShowingImportPicker = false })
        }
        .overlay {
            if let activityText {
                ZStack {
                    Color.black.opacity(0.5).ignoresSafeArea()
                    ProgressView(activityText)
                        .padding()
                        .background(Color.white.opacity(0.2), in: RoundedRectangle(cornerRadius: 12))
                        .foregroundColor(.orange)
                }
            }
        }
        .alert(item: $replacementNotice) { notice in
            Alert(title: Text(notice.title), message: Text(notice.message), dismissButton: .default(Text(language.text("common.done"))))
        }
        .alert(namePromptTitle, isPresented: isNamePromptPresented) {
            TextField(language.text("browser.name_placeholder"), text: $nameInput)
            Button(language.text("common.cancel"), role: .cancel) { namePrompt = nil }
            Button(language.text("common.done")) { commitNamePrompt() }
        } message: {
            Text(language.text("browser.name_message"))
        }
    }

    private var sortOrder: FileBrowserSortOrder {
        FileBrowserSortOrder(rawValue: sortOrderRaw) ?? .nameAscending
    }

    private var sortMenu: some View {
        Menu {
            Picker(language.text("browser.sort"), selection: $sortOrderRaw) {
                ForEach(FileBrowserSortOrder.allCases) { order in
                    Label(language.text(order.localizationKey), systemImage: order.systemImage).tag(order.rawValue)
                }
            }
        } label: {
            Image(systemName: "arrow.up.arrow.down").foregroundColor(.orange)
        }
    }

    @ViewBuilder
    private func fileRow(_ entry: FileEntry) -> some View {
        let rowContent = HStack {
            Image(systemName: entry.isDirectory ? "folder.fill" : "doc.text")
                .foregroundColor(entry.isDirectory ? .orange : .white)
            VStack(alignment: .leading) {
                Text(entry.name).foregroundColor(.white)
                Text(entry.date).foregroundColor(.gray).font(.caption)
            }
            Spacer()
            if entry.isDirectory { Image(systemName: "chevron.right").foregroundColor(.gray) }
        }

        if isSelecting {
            Button { toggleSelection(entry) } label: {
                rowContent.background(selectedEntryIDs.contains(entry.id) ? Color.orange.opacity(0.3) : Color.clear)
            }.buttonStyle(.plain)
        } else if entry.isDirectory {
            NavigationLink(value: FileBrowserDestination(containerPath: containerPath, startPath: entry.path, title: entry.name, bundleID: bundleID)) {
                rowContent
            }.contextMenu { fileActions(for: entry) }
        } else {
            NavigationLink { FileQuickLookView(file: entry) } label: {
                rowContent
            }.contextMenu { fileActions(for: entry) }
        }
    }

    @ViewBuilder
    private func fileActions(for entry: FileEntry) -> some View {
        Button { prepareTransfer([entry], mode: .copy) } label: { Label(language.text("browser.copy"), systemImage: "doc.on.doc") }
        Button { prepareTransfer([entry], mode: .move) } label: { Label(language.text("browser.move"), systemImage: "folder") }
        if bundleID != nil {
            Button { requestPatchCreation(for: entry) } label: { Label(language.text("browser.create_patch"), systemImage: "shippingbox") }
        }
        Button { presentNamePrompt(.rename(entry)) } label: { Label(language.text("browser.rename"), systemImage: "pencil") }
        Button(role: .destructive) { deleteTargets = [entry] } label: { Label(language.text("browser.delete"), systemImage: "trash") }
    }

    // --- MANTENDO TODA A LÓGICA ORIGINAL ABAIXO ---
    // (As funções load, commitNamePrompt, performFileOperation, etc, permanecem idênticas ao original)

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

    private func requestPatchCreation(for entry: FileEntry) {
        guard let bundleID else { return }
        let itemURL = URL(fileURLWithPath: entry.path, isDirectory: entry.isDirectory)
        let containerURL = URL(fileURLWithPath: containerPath, isDirectory: true)
        activityText = language.text("patch.preparing_from_browser")
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let draft = try PatchDraftService.makeDraft(bundleID: bundleID, containerRoot: containerURL, itemURL: itemURL, suggestedName: entry.name)
                DispatchQueue.main.async {
                    activityText = nil
                    patchDraftCoordinator.present(draft)
                }
            } catch {
                DispatchQueue.main.async { activityText = nil }
            }
        }
    }

    private func toggleSelectionMode() { isSelecting.toggle(); if !isSelecting { selectedEntryIDs.removeAll() } }
    private func toggleSelection(_ entry: FileEntry) { if selectedEntryIDs.remove(entry.id) == nil { selectedEntryIDs.insert(entry.id) } }
    private func prepareTransfer(_ entries: [FileEntry], mode: FileTransferMode) {
        fileOperationCoordinator.prepare(entries.map { URL(fileURLWithPath: $0.path, isDirectory: $0.isDirectory) }, mode: mode)
        isSelecting = false
    }
    private func beginPaste(_ payload: FileOperationPayload) {
        transferSession = FileTransferSession(payload: payload, destinationDirectory: URL(fileURLWithPath: currentPath, isDirectory: true))
        fileOperationCoordinator.clear()
        DispatchQueue.main.async { processNextTransfer() }
    }
    private func processNextTransfer() {
        guard var session = transferSession, let sourceURL = session.takeNext() else { return }
        let destinationURL = session.destinationDirectory.appendingPathComponent(sourceURL.lastPathComponent)
        performTransfer(sourceURL: sourceURL, policy: .replace)
    }
    private func performTransfer(sourceURL: URL, policy: FileConflictPolicy) {
        guard let session = transferSession else { return }
        activityText = "Transferindo..."
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                _ = try FileManagerService.transferItem(at: sourceURL, into: session.destinationDirectory, mode: session.mode, conflictPolicy: policy)
                DispatchQueue.main.async { activityText = nil; load(); processNextTransfer() }
            } catch {
                DispatchQueue.main.async { activityText = nil }
            }
        }
    }
    private func requestImportPicker() { isShowingImportPicker = true }
    private func handleImportPickerResult(_ result: Result<[URL], Error>) {
        if case .success(let urls) = result {
            importSession = FileImportSession(destinationDirectory: URL(fileURLWithPath: currentPath, isDirectory: true), sourceURLs: urls)
            processNextImport()
        }
    }
    private func processNextImport() {
        guard var session = importSession, let sourceURL = session.takeNext() else { return }
        performImport(sourceURL: sourceURL, destinationURL: URL(fileURLWithPath: currentPath + "/" + sourceURL.lastPathComponent), replaceExisting: true)
    }
    private func performImport(sourceURL: URL, destinationURL: URL, replaceExisting: Bool) {
        activityText = "Importando..."
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                _ = try FileManagerService.importFile(sourceURL, into: URL(fileURLWithPath: self.currentPath, isDirectory: true), replaceExisting: replaceExisting)
                DispatchQueue.main.async { activityText = nil; self.load(); self.processNextImport() }
            } catch {
                DispatchQueue.main.async { activityText = nil }
            }
        }
    }
    private func commitNamePrompt() {
        guard let prompt = namePrompt else { return }
        let name = nameInput
        namePrompt = nil
        let dir = URL(fileURLWithPath: currentPath, isDirectory: true)
        performFileOperation(activity: "Processando...", operationName: "op") {
            if case .createFile = prompt.action { return try FileManagerService.createFile(named: name, in: dir).path }
            if case .createFolder = prompt.action { return try FileManagerService.createFolder(named: name, in: dir).path }
            return ""
        }
    }
    private func performFileOperation(activity: String, operationName: String, successNotice: ((String) -> FileReplacementNotice)? = nil, work: @escaping () throws -> String) {
        activityText = activity
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let path = try work()
                DispatchQueue.main.async { activityText = nil; self.load(); self.operationNotice = successNotice?(path) }
            } catch {
                DispatchQueue.main.async { activityText = nil }
            }
        }
    }
    private func fileEmptyView: some View {
        VStack { Image(systemName: "folder").foregroundColor(.gray); Text(language.text("browser.empty_folder")).foregroundColor(.gray) }
    }
    private func searchEmptyView: some View {
        VStack { Image(systemName: "magnifyingglass").foregroundColor(.gray); Text(language.text("browser.search_empty")).foregroundColor(.gray) }
    }
    private var isNamePromptPresented: Binding<Bool> {
        Binding(get: { namePrompt != nil }, set: { if !$0 { namePrompt = nil } })
    }
    private var namePromptTitle: String {
        switch namePrompt?.action {
        case .createFile: return "Novo Arquivo"
        case .createFolder: return "Nova Pasta"
        case .rename: return "Renomear"
        default: return ""
        }
    }
}
