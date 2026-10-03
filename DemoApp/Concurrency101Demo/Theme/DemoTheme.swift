import SwiftUI

enum DemoTheme {
    static let void = Color(red: 0.09, green: 0.08, blue: 0.12)
    static let phosphor = Color(red: 0.91, green: 0.72, blue: 0.43)
    static let cyan = Color(red: 0.49, green: 0.72, blue: 0.79)
    static let freeze = Color(red: 0.77, green: 0.36, blue: 0.36)
    static let hit = Color(red: 0.42, green: 0.78, blue: 0.50)
    static let muted = Color.white.opacity(0.45)

    static let syntaxBrand = phosphor
    static let syntaxLog = Color(red: 0.93, green: 0.50, blue: 0.70)
    static let syntaxKeyword = Color(red: 0.73, green: 0.64, blue: 0.93)
    static let syntaxType = cyan
    static let syntaxCall = Color(red: 0.96, green: 0.84, blue: 0.52)
    static let syntaxString = Color(red: 0.63, green: 0.84, blue: 0.58)
    static let syntaxNumber = Color(red: 0.95, green: 0.68, blue: 0.42)
    static let syntaxPlain = Color.white.opacity(0.86)
}
