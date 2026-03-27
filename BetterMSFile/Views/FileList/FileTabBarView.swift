import SwiftUI

struct FileTab: Identifiable, Equatable {
    let id = UUID()
    var name: String
    var breadcrumbs: [FileListViewModel.BreadcrumbItem]
    var cacheKey: String?

    static func == (lhs: FileTab, rhs: FileTab) -> Bool {
        lhs.id == rhs.id
    }
}

struct FileTabBarView: View {
    @Binding var tabs: [FileTab]
    @Binding var activeTabId: UUID?
    var onSelect: (FileTab) -> Void
    var onClose: (FileTab) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 0) {
                ForEach(tabs) { tab in
                    tabButton(tab)
                }

                // New tab button
                Button {
                    let newTab = FileTab(name: "My Files", breadcrumbs: [], cacheKey: nil)
                    tabs.append(newTab)
                    activeTabId = newTab.id
                    onSelect(newTab)
                } label: {
                    Image(systemName: "plus")
                        .font(.caption2)
                        .padding(6)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 4)
        }
        .frame(height: 28)
        .background(.bar)
    }

    @ViewBuilder
    private func tabButton(_ tab: FileTab) -> some View {
        let isActive = activeTabId == tab.id

        HStack(spacing: 4) {
            Text(tab.name)
                .font(.caption)
                .lineLimit(1)
                .frame(maxWidth: 120)

            if tabs.count > 1 {
                Button {
                    onClose(tab)
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 8, weight: .bold))
                }
                .buttonStyle(.plain)
                .foregroundStyle(.tertiary)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isActive ? Color.accentColor.opacity(0.12) : Color.clear)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(isActive ? Color.accentColor.opacity(0.3) : Color.clear, lineWidth: 1)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            activeTabId = tab.id
            onSelect(tab)
        }
    }
}
