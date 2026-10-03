import SwiftUI
#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

enum DemoSourceType {
    static let storageKey = "demo.sourceFontSize"
    static let sizes = [10, 11, 12, 13, 14, 16, 18, 20, 24]
    static var defaultSize: Int { Int(DemoLayout.typeSize(12)) }

    static func gutterWidth(fontSize: CGFloat, lineCount: Int) -> CGFloat {
        lineCount >= 100 ? max(28, fontSize + 14) : max(22, fontSize + 10)
    }

    /// Columns of leading indent. A tab counts as four spaces, matching Xcode.
    static func leadingIndentColumns(_ line: String) -> Int {
        var columns = 0
        for character in line {
            switch character {
            case " ": columns += 1
            case "\t": columns += 4
            default: return columns
            }
        }
        return columns
    }

    static func monoAdvance(fontSize: CGFloat) -> CGFloat {
        #if os(iOS)
        let width = (" " as NSString).size(withAttributes: [
            .font: UIFont.monospacedSystemFont(ofSize: fontSize, weight: .regular)
        ]).width
        #elseif os(macOS)
        let width = (" " as NSString).size(withAttributes: [
            .font: NSFont.monospacedSystemFont(ofSize: fontSize, weight: .regular)
        ]).width
        #else
        let width = fontSize * 0.6
        #endif
        return width > 0 ? width : fontSize * 0.6
    }
}
