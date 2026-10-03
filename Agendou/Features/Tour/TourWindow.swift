import SwiftUI
import UIKit

/// A window above the app for the tour: it covers tabs, navigation bars and sheets alike, and takes every
/// touch, so only the balloon responds.
final class TourWindow {
    private var window: UIWindow?

    func show(_ controller: TourController) {
        guard window == nil,
            let scene = UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }).first
        else { return }
        let safeArea = scene.windows.first { $0.windowLevel == .normal }?.safeAreaInsets ?? .zero
        let host = UIHostingController(
            rootView: TourOverlay(safeArea: safeArea).environment(controller).agendouEnvironment())
        host.view.backgroundColor = .clear
        host.view.accessibilityViewIsModal = true
        let window = UIWindow(windowScene: scene)
        window.windowLevel = .alert + 1
        window.rootViewController = host
        window.isHidden = false
        self.window = window
    }

    func hide() {
        window?.isHidden = true
        window = nil
    }
}
