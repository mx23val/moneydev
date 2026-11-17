import UIKit

@MainActor
public enum ShareSheetPresenter {
    public static func present(items: [Any], completion: (() -> Void)? = nil) {
        guard let windowScene = UIApplication.shared.connectedScenes.first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene ?? UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootVC = windowScene.windows.first(where: { $0.isKeyWindow })?.rootViewController ?? windowScene.windows.first?.rootViewController else {
            return
        }
        
        // Buscar el controlador de vista visible superior
        var topVC = rootVC
        while let presented = topVC.presentedViewController, !presented.isBeingDismissed {
            topVC = presented
        }
        
        let activityVC = UIActivityViewController(activityItems: items, applicationActivities: nil)
        
        // Protección crítica para iPad y Mac Catalyst (evita crash NSGenericException)
        if let popover = activityVC.popoverPresentationController {
            popover.sourceView = topVC.view
            popover.sourceRect = CGRect(x: topVC.view.bounds.midX, y: topVC.view.bounds.midY, width: 0, height: 0)
            popover.permittedArrowDirections = []
        }
        
        // Si hay una animación de cierre o apertura en curso, esperar 0.3 segundos antes de presentar
        if topVC.isBeingDismissed || topVC.isBeingPresented {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                present(items: items, completion: completion)
            }
            return
        }
        
        topVC.present(activityVC, animated: true, completion: completion)
    }
}
