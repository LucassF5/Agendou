import SwiftUI
import UIKit

/// A window above the app for the tour: it covers tabs, navigation bars and sheets alike, and takes every
/// touch, so only the balloon responds. For VoiceOver it is modal.
final class TourWindow {
    private var window: UIWindow?

    func show(_ controller: TourController) {
        guard window == nil,
            let scene = UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }).first
        else { return }
        let host = UIHostingController(rootView: TourOverlay().environment(controller).agendouEnvironment())
        host.view.backgroundColor = .clear
        host.view.accessibilityViewIsModal = true
        let window = UIWindow(windowScene: scene)
        window.windowLevel = .alert + 1
        window.rootViewController = host
        window.accessibilityViewIsModal = true
        window.isHidden = false
        self.window = window
        // VoiceOver moves to the balloon instead of staying on what was under the overlay.
        UIAccessibility.post(notification: .screenChanged, argument: host.view)
    }

    /// Tells VoiceOver the balloon changed, so the new step is read.
    func stepChanged() {
        guard let view = window?.rootViewController?.view else { return }
        UIAccessibility.post(notification: .layoutChanged, argument: view)
    }

    func hide() {
        window?.isHidden = true
        window = nil
    }
}
