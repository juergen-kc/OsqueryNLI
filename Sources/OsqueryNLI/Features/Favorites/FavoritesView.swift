import SwiftUI

struct FavoritesView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    var onSelect: ((String) -> Void)?

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Favorites")
                    .font(.headline)
                Spacer()
                Text("\(appState.favorites.count) saved")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding()

            Divider()

            if appState.favorites.isEmpty {
                emptyState
            } else {
                favoritesList
            }
        }
        .frame(minWidth: 400, minHeight: 300)
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "star")
                .font(.system(size: 48))
                .foregroundStyle(.tertiary)

            Text("No Favorites Yet")
                .font(.headline)
                .foregroundStyle(.secondary)

            Text("Run a query and click the star button\nto save it to your favorites")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var favoritesList: some View {
        List {
            ForEach(appState.favorites) { favorite in
                FavoriteRowView(
                    favorite: favorite,
                    onSelect: {
                        onSelect?(favorite.query)
                        dismiss()
                    },
                    onDelete: {
                        appState.removeFromFavorites(favorite)
                    }
                )
            }
        }
        .listStyle(.inset)
    }
}

struct FavoriteRowView: View {
    let favorite: FavoriteQuery
    let onSelect: () -> Void
    let onDelete: () -> Void
    @State private var isHovering = false

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "star.fill")
                .foregroundStyle(.yellow)
                .font(.caption)

            VStack(alignment: .leading, spacing: 2) {
                if let name = favorite.name, !name.isEmpty {
                    Text(name)
                        .font(.body.weight(.medium))
                    Text(favorite.query)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                } else {
                    Text(favorite.query)
                        .font(.body)
                        .lineLimit(2)
                }

                Text(favorite.createdAt, style: .relative)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            Spacer()

            if isHovering {
                HStack(spacing: 8) {
                    Button {
                        onSelect()
                    } label: {
                        Image(systemName: "play.fill")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .help("Run this query")

                    Button(role: .destructive) {
                        onDelete()
                    } label: {
                        Image(systemName: "trash")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .help("Remove from favorites")
                }
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .onHover { hovering in
            isHovering = hovering
        }
        .onTapGesture(count: 2) {
            onSelect()
        }
    }
}
