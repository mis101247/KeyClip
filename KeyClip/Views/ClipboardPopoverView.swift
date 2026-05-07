import SwiftUI

struct ClipboardPopoverView: View {
    @ObservedObject var store: ClipboardHistoryStore
    @State private var searchQuery = ""

    let onSelect: (ClipboardHistoryItem) -> Void
    let onClose: () -> Void

    private var trimmedSearchQuery: String {
        searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var filteredItems: [ClipboardHistoryItem] {
        guard !trimmedSearchQuery.isEmpty else {
            return store.items
        }

        return store.items.filter { item in
            item.content.range(
                of: trimmedSearchQuery,
                options: [.caseInsensitive, .diacriticInsensitive]
            ) != nil
        }
    }

    var body: some View {
        ZStack {
            Color(nsColor: .controlBackgroundColor)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                header

                listSection

                footer
            }
            .frame(width: 400, height: 520)

            hotkeyButtons
        }
        .onExitCommand {
            onClose()
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Clipboard")
                    .font(.headline)

                Spacer()

                Text("\(store.items.count)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(
                        Capsule()
                            .fill(Color(nsColor: .quaternaryLabelColor))
                    )
            }

            searchField
        }
        .padding(.horizontal, 12)
        .padding(.top, 10)
        .padding(.bottom, 10)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color(nsColor: .separatorColor))
                .frame(height: 1)
        }
    }

    private var searchField: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.secondary)

            TextField("Search clipboard…", text: $searchQuery)
                .textFieldStyle(.plain)

            if !searchQuery.isEmpty {
                Button {
                    searchQuery = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("Clear search")
            }
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 7)
        .background(
            RoundedRectangle(cornerRadius: 7)
                .fill(Color(nsColor: .textBackgroundColor))
        )
    }

    @ViewBuilder
    private var listSection: some View {
        if store.items.isEmpty {
            emptyState(
                systemImage: "doc.on.clipboard",
                title: "No history yet",
                hint: "Copy something to get started"
            )
        } else if filteredItems.isEmpty {
            emptyState(
                systemImage: "magnifyingglass",
                title: "No matches",
                hint: "No results for '\(trimmedSearchQuery)'"
            )
        } else {
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(Array(filteredItems.enumerated()), id: \.element.id) { index, item in
                        ClipboardHistoryRowView(
                            item: item,
                            shortcutLabel: shortcutLabel(for: index)
                        )
                        .contentShape(Rectangle())
                        .onTapGesture {
                            onSelect(item)
                        }

                        if index < filteredItems.count - 1 {
                            Divider()
                                .overlay(Color(nsColor: .separatorColor))
                                .padding(.horizontal, 12)
                        }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
            }
        }
    }

    private var footer: some View {
        HStack {
            Button("Clear History") {
                store.clear()
            }
            .disabled(store.items.isEmpty)

            Spacer()

            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(Color(nsColor: .separatorColor))
                .frame(height: 1)
        }
    }

    private var hotkeyButtons: some View {
        VStack {
            ForEach(0..<4, id: \.self) { index in
                Button("") {
                    selectFilteredItem(at: index)
                }
                .keyboardShortcut(KeyEquivalent(Character("\(index + 1)")), modifiers: .command)
            }
        }
        .frame(width: 0, height: 0)
        .opacity(0)
        .accessibilityHidden(true)
    }

    private func selectFilteredItem(at index: Int) {
        guard filteredItems.indices.contains(index) else { return }

        onSelect(filteredItems[index])
    }

    private func shortcutLabel(for index: Int) -> String? {
        guard index < 4 else { return nil }

        return "⌘\(index + 1)"
    }

    private func emptyState(systemImage: String, title: String, hint: String) -> some View {
        VStack(spacing: 8) {
            Spacer(minLength: 0)

            Image(systemName: systemImage)
                .font(.system(size: 32))
                .foregroundStyle(.secondary)

            Text(title)
                .font(.headline)

            Text(hint)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(24)
    }
}
