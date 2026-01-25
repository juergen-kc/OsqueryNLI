import SwiftUI

/// Reusable search bar component with consistent styling
struct SearchBar: View {
    @Binding var text: String
    let placeholder: String
    let onClear: (() -> Void)?

    @FocusState private var isFocused: Bool

    init(
        text: Binding<String>,
        placeholder: String = "Search...",
        onClear: (() -> Void)? = nil
    ) {
        self._text = text
        self.placeholder = placeholder
        self.onClear = onClear
    }

    var body: some View {
        HStack(spacing: AppLayout.Spacing.sm) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: AppLayout.Icon.medium))
                .foregroundStyle(.secondary)

            TextField(placeholder, text: $text)
                .textFieldStyle(.plain)
                .focused($isFocused)

            if !text.isEmpty {
                Button {
                    clearSearch()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: AppLayout.Icon.medium))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Clear search")
                .transition(.opacity.combined(with: .scale))
            }
        }
        .padding(AppLayout.Spacing.sm)
        .background(.background)
        .animation(.easeInOut(duration: AppAnimation.fast), value: text.isEmpty)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Search field")
    }

    private func clearSearch() {
        text = ""
        onClear?()
        isFocused = true
    }
}

// MARK: - Styled Variants

extension SearchBar {
    /// Search bar with rounded border
    func bordered() -> some View {
        self
            .clipShape(RoundedRectangle(cornerRadius: AppLayout.CornerRadius.md))
            .overlay(
                RoundedRectangle(cornerRadius: AppLayout.CornerRadius.md)
                    .stroke(.quaternary, lineWidth: 1)
            )
    }

    /// Search bar with background fill
    func filled() -> some View {
        self
            .background(.quaternary.opacity(0.5))
            .clipShape(RoundedRectangle(cornerRadius: AppLayout.CornerRadius.md))
    }
}

// MARK: - Search Bar with Filter

/// Search bar with an additional filter picker
struct FilterableSearchBar<Filter: Hashable>: View {
    @Binding var text: String
    @Binding var filter: Filter
    let placeholder: String
    let filters: [Filter]
    let filterLabel: (Filter) -> String

    init(
        text: Binding<String>,
        filter: Binding<Filter>,
        placeholder: String = "Search...",
        filters: [Filter],
        filterLabel: @escaping (Filter) -> String
    ) {
        self._text = text
        self._filter = filter
        self.placeholder = placeholder
        self.filters = filters
        self.filterLabel = filterLabel
    }

    var body: some View {
        HStack(spacing: AppLayout.Spacing.sm) {
            SearchBar(text: $text, placeholder: placeholder)

            Picker("", selection: $filter) {
                ForEach(filters, id: \.self) { filterOption in
                    Text(filterLabel(filterOption)).tag(filterOption)
                }
            }
            .pickerStyle(.menu)
            .frame(width: 80)
        }
    }
}

#Preview {
    VStack(spacing: 20) {
        Group {
            Text("Plain")
                .font(.caption)
            SearchBar(text: .constant("test query"))
        }

        Group {
            Text("Bordered")
                .font(.caption)
            SearchBar(text: .constant(""), placeholder: "Search history...")
                .bordered()
        }

        Group {
            Text("Filled")
                .font(.caption)
            SearchBar(text: .constant("osquery"), placeholder: "Filter tables...")
                .filled()
        }
    }
    .padding()
    .frame(width: 350)
}
