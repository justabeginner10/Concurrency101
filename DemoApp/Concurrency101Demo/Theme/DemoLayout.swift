import SwiftUI
#if os(iOS)
import UIKit
#endif

enum DemoLayout {
    static var isPadLike: Bool {
        #if os(iOS)
        UIDevice.current.userInterfaceIdiom != .phone
        #else
        true
        #endif
    }

    /// Stacked phone chrome is portrait iPhone only.
    /// Landscape iPhone, iPad, and Mac get the wide rooms.
    static func usesPhoneChrome(verticalSizeClass: UserInterfaceSizeClass?) -> Bool {
        #if os(iOS)
        UIDevice.current.userInterfaceIdiom == .phone && verticalSizeClass != .compact
        #else
        false
        #endif
    }

    static func sidebarWidth(verticalSizeClass: UserInterfaceSizeClass?) -> CGFloat {
        verticalSizeClass == .compact ? 240 : 320
    }

    /// Two extra points on iPad/Mac so copy is easier to read at tablet distance.
    static func typeSize(_ phone: CGFloat) -> CGFloat {
        isPadLike ? phone + 2 : phone
    }
}

private enum UsesPhoneChromeKey: EnvironmentKey {
    static let defaultValue: Bool = {
        #if os(iOS)
        UIDevice.current.userInterfaceIdiom == .phone
        #else
        false
        #endif
    }()
}

extension EnvironmentValues {
    var usesPhoneChrome: Bool {
        get { self[UsesPhoneChromeKey.self] }
        set { self[UsesPhoneChromeKey.self] = newValue }
    }
}
