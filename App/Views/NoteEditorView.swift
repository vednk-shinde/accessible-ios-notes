import NotesCore
import SwiftUI

struct NoteEditorView: View {
    @EnvironmentObject private var store: NoteStore
    @State private var draft: NoteSnapshot
    @State private var saveTask: Task<Void, Never>?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @FocusState private var bodyFocused: Bool

    init(note: NoteSnapshot) { _draft = State(initialValue: note) }

    var body: some View {
        Form {
            Section {
                TextField("Title", text: $draft.title)
                    .font(.title3.weight(.semibold))
                    .accessibilityIdentifier("titleField")
            }
            Section {
                TextEditor(text: $draft.body)
                    .font(.body) // semantic font => honours Dynamic Type up to the accessibility sizes
                    .frame(minHeight: 240)
                    .focused($bodyFocused)
                    .accessibilityLabel("Note body")
                    .accessibilityValue(AccessibilityPhrases.rowValue(draft))
                    .accessibilityIdentifier("bodyField")
            } footer: {
                Label("End-to-end encrypted", systemImage: "lock.fill").font(.footnote).foregroundStyle(.primary)
            }
        }
        .navigationTitle(draft.displayTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    draft.isPinned.toggle()
                    commit()
                    UIAccessibility.post(notification: .announcement, argument: draft.isPinned ? "Pinned" : "Unpinned")
                } label: {
                    Label(draft.isPinned ? "Unpin" : "Pin", systemImage: draft.isPinned ? "pin.fill" : "pin")
                }
                .accessibilityValue(draft.isPinned ? "Pinned" : "Not pinned")
            }
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") { bodyFocused = false; commit() }
            }
        }
        // Debounced autosave: avoids re-encrypting and re-syncing on every keystroke.
        .onChange(of: draft.title) { scheduleSave() }
        .onChange(of: draft.body) { scheduleSave() }
        .onDisappear { saveTask?.cancel(); commit() }
        .animation(reduceMotion ? nil : .default, value: draft.isPinned)
    }

    private func scheduleSave() {
        saveTask?.cancel()
        saveTask = Task {
            try? await Task.sleep(for: .milliseconds(600))
            if !Task.isCancelled { commit() }
        }
    }

    private func commit() { store.update(draft) }
}
