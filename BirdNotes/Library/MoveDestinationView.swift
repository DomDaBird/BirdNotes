import SwiftUI
import BirdNotesCore

struct MoveDestinationView: View {
    let store: DocumentStore
    let item: BirdNotesCore.LibraryItem
    let onSelect: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var folderPaths: [String] = []
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            List(validDestinations, id: \.self) { path in
                Button {
                    onSelect(path)
                    dismiss()
                } label: {
                    Label(
                        path.isEmpty ? "Meine Dokumente" : path,
                        systemImage: path.isEmpty ? "externaldrive" : "folder"
                    )
                }
            }
            .navigationTitle("„\(item.name)“ verschieben")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
            }
            .task {
                do {
                    folderPaths = try await store.allFolderPaths()
                } catch {
                    errorMessage = error.localizedDescription
                }
            }
            .overlay {
                if folderPaths.isEmpty, errorMessage == nil { ProgressView() }
            }
            .alert("Fehler", isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("OK") { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "Unbekannter Fehler")
            }
        }
    }

    private var validDestinations: [String] {
        let normalizedParent = item.relativePath
            .split(separator: "/")
            .dropLast()
            .joined(separator: "/")
        return folderPaths.filter { path in
            guard path != normalizedParent else { return false }
            if item.kind == .folder {
                return path != item.relativePath && !path.hasPrefix(item.relativePath + "/")
            }
            return true
        }
    }
}
