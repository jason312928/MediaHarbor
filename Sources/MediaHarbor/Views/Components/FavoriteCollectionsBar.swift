import SwiftUI

enum FavoriteCollectionEditor: Identifiable {
    case create
    case rename(FavoriteCollection)

    var id: String {
        switch self {
        case .create: "create"
        case .rename(let collection): "rename-\(collection.id)"
        }
    }
}

struct FavoriteCollectionsBar: View {
    let collections: [FavoriteCollection]
    let items: [FavoriteItem]
    @Binding var selection: FavoriteCollectionSelection
    let onCreate: () -> Void
    let onRename: (FavoriteCollection) -> Void
    let onDelete: (FavoriteCollection) -> Void
    @Environment(\.appLanguage) private var language

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack {
                Text(L10n.text("favorite_groups", language))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Button(action: onCreate) {
                    Label(L10n.text("new_group", language), systemImage: "plus")
                }
                .buttonStyle(.borderless)
                .controlSize(.small)
            }

            ScrollView(.horizontal) {
                HStack(spacing: 9) {
                    collectionButton(
                        title: L10n.text("all_favorites", language),
                        count: items.count,
                        symbol: "star.fill",
                        tint: .yellow,
                        value: .all
                    )

                    ForEach(collections) { collection in
                        collectionButton(
                            title: collection.name,
                            count: items.filter { $0.collectionID == collection.id }.count,
                            symbol: "folder.fill",
                            tint: .accentColor,
                            value: .collection(collection.id)
                        )
                        .contextMenu {
                            Button(L10n.text("rename_group", language)) { onRename(collection) }
                            Button(L10n.text("delete_group", language), role: .destructive) { onDelete(collection) }
                        }
                    }

                    collectionButton(
                        title: L10n.text("ungrouped", language),
                        count: items.filter { $0.collectionID == nil }.count,
                        symbol: "tray",
                        tint: .secondary,
                        value: .ungrouped
                    )
                }
                .padding(.vertical, 1)
            }
            .scrollIndicators(.hidden)
        }
    }

    private func collectionButton(
        title: String,
        count: Int,
        symbol: String,
        tint: Color,
        value: FavoriteCollectionSelection
    ) -> some View {
        FavoriteCollectionChip(
            title: title,
            count: count,
            symbol: symbol,
            tint: tint,
            isSelected: selection == value,
            action: { selection = value }
        )
    }
}

private struct FavoriteCollectionChip: View {
    let title: String
    let count: Int
    let symbol: String
    let tint: Color
    let isSelected: Bool
    let action: () -> Void
    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 7) {
                Image(systemName: symbol)
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(isSelected ? .white : tint)
                    .frame(width: 16)
                Text(title)
                    .font(.callout.weight(.semibold))
                    .lineLimit(1)
                Text(count, format: .number)
                    .font(.caption2.monospacedDigit().weight(.semibold))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(
                        isSelected ? Color.white.opacity(0.18) : Color.secondary.opacity(0.1),
                        in: Capsule()
                    )
            }
            .foregroundStyle(isSelected ? Color.white : Color.primary)
            .padding(.horizontal, 11)
            .frame(height: 34)
            .background(backgroundColor, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .strokeBorder(borderColor, lineWidth: 1)
            }
            .contentShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
        }
        .buttonStyle(.plain)
        .fixedSize()
        .onHover { hovering in isHovering = hovering }
        .animation(.easeOut(duration: 0.12), value: isSelected)
        .animation(.easeOut(duration: 0.08), value: isHovering)
    }

    private var backgroundColor: Color {
        if isSelected { return .accentColor }
        return isHovering ? Color.secondary.opacity(0.1) : Color.secondary.opacity(0.055)
    }

    private var borderColor: Color {
        isSelected ? .accentColor : Color.secondary.opacity(isHovering ? 0.2 : 0.12)
    }
}

struct FavoriteCollectionEditorSheet: View {
    let editor: FavoriteCollectionEditor
    let onSave: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appLanguage) private var language
    @State private var name = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text(L10n.text(isCreating ? "new_group" : "rename_group", language))
                .font(.title2.bold())
            TextField(L10n.text("group_name", language), text: $name)
                .textFieldStyle(.roundedBorder)
                .onSubmit(save)
            HStack {
                Spacer()
                Button(L10n.text("cancel", language)) { dismiss() }
                Button(L10n.text(isCreating ? "create" : "save", language), action: save)
                    .buttonStyle(.borderedProminent)
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(22)
        .frame(width: 360)
        .onAppear {
            if case .rename(let collection) = editor { name = collection.name }
        }
    }

    private var isCreating: Bool {
        if case .create = editor { return true }
        return false
    }

    private func save() {
        let value = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return }
        onSave(value)
        dismiss()
    }
}
