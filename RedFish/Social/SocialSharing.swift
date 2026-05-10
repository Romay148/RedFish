import Foundation
import UIKit

/// Point d’extension pour un futur partage distant (API) ; V1 : partage système uniquement.
protocol SocialSharing: AnyObject {
    func share(images: [UIImage], from viewController: UIViewController?)
}

final class SystemSocialSharing: SocialSharing {
    func share(images: [UIImage], from viewController: UIViewController?) {
        guard !images.isEmpty else { return }
        let items: [Any] = images.count == 1 ? [images[0]] : images
        DispatchQueue.main.async {
            let av = UIActivityViewController(activityItems: items, applicationActivities: nil)
            av.popoverPresentationController?.sourceView = viewController?.view
            viewController?.present(av, animated: true)
        }
    }
}
