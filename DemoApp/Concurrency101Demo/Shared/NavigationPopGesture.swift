import SwiftUI
#if os(iOS)
import UIKit
#endif

extension View {
    /// Turns off the leading-edge swipe that pops the current screen.
    func navigationPopGestureDisabled(_ disabled: Bool = true) -> some View {
        #if os(iOS)
        background { NavigationPopGestureLock(isLocked: disabled) }
        #else
        self
        #endif
    }
}

#if os(iOS)
private struct NavigationPopGestureLock: UIViewControllerRepresentable {
    var isLocked: Bool

    func makeUIViewController(context: Context) -> Controller {
        Controller()
    }

    func updateUIViewController(_ controller: Controller, context: Context) {
        controller.isLocked = isLocked
        controller.apply()
    }

    final class Controller: UIViewController {
        var isLocked = false

        override func viewDidAppear(_ animated: Bool) {
            super.viewDidAppear(animated)
            apply()
        }

        override func viewWillDisappear(_ animated: Bool) {
            super.viewWillDisappear(animated)
            enclosingNavigationController?.interactivePopGestureRecognizer?.isEnabled = true
        }

        func apply() {
            enclosingNavigationController?.interactivePopGestureRecognizer?.isEnabled = !isLocked
        }

        private var enclosingNavigationController: UINavigationController? {
            var current: UIViewController? = self
            while let controller = current {
                if let nav = controller as? UINavigationController {
                    return nav
                }
                if let nav = controller.navigationController {
                    return nav
                }
                current = controller.parent
            }
            return nil
        }
    }
}
#endif
