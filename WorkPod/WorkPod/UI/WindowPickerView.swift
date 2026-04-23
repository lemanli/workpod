import SwiftUI

struct WindowPickerView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var windowManager = WindowManager.shared
    @State private var searchText = ""
    var onSelect: (WindowInfo) -> Void

    // Filtered window list based on search text
    var filteredWindows: [WindowInfo] {
        if searchText.isEmpty {
            return windowManager.windowList
        } else {
            return windowManager.windowList.filter { window in
                let displayName = window.displayName.lowercased()
                let query = searchText.lowercased()
                return displayName.contains(query)
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                TextField("搜索应用或窗口...", text: $searchText)
                    .textFieldStyle(.roundedBorder)
                    .padding(.leading)

                Button("刷新") {
                    windowManager.updateWindowList()
                }
                .padding(.trailing)
            }
            .padding()
            .background(Color(NSColor.windowBackgroundColor))

            Divider()

            List(filteredWindows) { window in
                HStack {
                    VStack(alignment: .leading) {
                        Text(window.displayName)
                            .font(.body)
                    }
                    Spacer()
                    Button("选择") {
                        onSelect(window)
                        dismiss()
                    }
                    .buttonStyle(.bordered)
                }
                .padding(.vertical, 4)
            }
            .listStyle(.plain)
            .frame(minWidth: 400, minHeight: 500)
        }
    }
}
