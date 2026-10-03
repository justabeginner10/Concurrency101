import SwiftUI

struct PanelSizeButton: View {
    let isMaximized: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: isMaximized
                ? "arrow.down.right.and.arrow.up.left"
                : "arrow.up.left.and.arrow.down.right")
                .font(.system(size: DemoLayout.typeSize(12), weight: .medium))
                .foregroundStyle(DemoTheme.cyan)
                .frame(width: 28, height: 28)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isMaximized ? "Minimize" : "Maximize")
    }
}
