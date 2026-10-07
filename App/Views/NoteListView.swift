import NotesCore
import SwiftUI

struct NoteListView: View {
    @EnvironmentObject private var store: NoteStore
    @State private var query = ""
    @State private var path: [UUID] = []
    @AccessibilityFocusState private var focusedNote: UUID?

    private var visible: [NoteSnapshot] { NoteSearch.filter(store.notes, query: query) }

    var body: some View {
        NavigationStack(path: $path) {
            List {
                ForEach(visible) { note in
                    NavigationLink(value: note.id) { NoteRow(note: note) }
                        .accessibilityFocused($focusedNote, equals: note.id)
                        // Alternatives to swipe gestures, reachable from the VoiceOver
                        // actions rotor and from Switch Control / AssistiveTouch menus.
                        .accessibilityAction(named: note.isPinned ? "Unpin" : "Pin") { store.togglePin(note) }
                        .accessibilityAction(named: "Delete") { store.delete(note) }
                        .swipeActions(edge: .leading) {
                            Button { store.togglePin(note) } label: {
                                Label(note.isPinned ? "Unpin" : "Pin", systemImage: note.isPinned ? "pin.slash" : "pin")
                            }.tint(.indigo)
                        }
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) { store.delete(note) } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                }
            }
            .overlay { if visible.isEmpty { EmptyState(isSearching: !query.isEmpty) } }
            .navigationTitle("Notes")
            .searchable(text: $query, prompt: "Search notes")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: newNote) { Label("New note", systemImage: "square.and.pencil") }
                        .accessibilityHint("Creates an empty note and opens it")
                        .accessibilityIdentifier("newNoteButton")
                }
            }
            .navigationDestination(for: UUID.self) { id in
                if let note = store.notes.first(where: { $0.id == id }) {
                    NoteEditorView(note: note)
                }
            }
            .alert("Something went wrong", isPresented: Binding(get: { store.lastError != nil }, set: { if !$0 { store.lastError = nil } })) {
                Button("OK", role: .cancel) {}
            } message: { Text(store.lastError ?? "") }
        }
        // Custom rotor: VoiceOver users can flick through pinned notes only.
        .accessibilityRotor("Pinned notes") {
            ForEach(store.notes.filter(\.isPinned)) { note in
                AccessibilityRotorEntry(note.displayTitle, id: note.id)
            }
        }
    }

    private func newNote() {
        let note = store.createNote()
        path.append(note.id)
    }
}

private struct NoteRow: View {
    let note: NoteSnapshot
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                if note.isPinned {
                    // Shape + text, never colour alone, conveys "pinned".
                    Image(systemName: "pin.fill").font(.headline).foregroundStyle(.primary)
                        .accessibilityHidden(true)
                }
                Text(note.displayTitle).font(.headline).lineLimit(2)
            }
            Text(note.body.isEmpty ? "No additional text" : note.body)
                .font(.subheadline).foregroundStyle(.secondary).lineLimit(2)
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(AccessibilityPhrases.rowLabel(note))
        .accessibilityValue(AccessibilityPhrases.rowValue(note))
        .accessibilityHint("Opens the note")
    }
}

private struct EmptyState: View {
    let isSearching: Bool
    var body: some View {
        ContentUnavailableView(
            isSearching ? "No results" : "No notes yet",
            systemImage: isSearching ? "magnifyingglass" : "note.text",
            description: Text(isSearching ? "Try a different search." : "Tap New note to write your first one. Notes are end-to-end encrypted.")
        )
    }
}
