import SwiftUI
import UIKit
import Combine

@MainActor
public final class NumpadKeyboardManager: NSObject, ObservableObject {
    public static let shared = NumpadKeyboardManager()
    
    @Published public var isNumpadActive: Bool = false
    
    private override init() {
        super.init()
        NotificationCenter.default.addObserver(
            forName: UITextField.textDidBeginEditingNotification,
            object: nil,
            queue: .main
        ) { [weak self] note in
            if let tf = note.object as? UITextField {
                let type = tf.keyboardType
                let isNum = (type == .decimalPad || type == .numberPad || type == .phonePad || type == .asciiCapableNumberPad)
                Task { @MainActor in
                    self?.isNumpadActive = isNum
                    if isNum && tf.inputAccessoryView == nil {
                        tf.inputAccessoryView = Self.buildNumpadAccessoryView()
                        tf.reloadInputViews()
                    }
                }
            } else if let traits = note.object as? UITextInputTraits {
                let type = traits.keyboardType ?? .default
                let isNum = (type == .decimalPad || type == .numberPad || type == .phonePad || type == .asciiCapableNumberPad)
                Task { @MainActor in
                    self?.isNumpadActive = isNum
                }
            }
        }
        
        NotificationCenter.default.addObserver(
            forName: UITextView.textDidBeginEditingNotification,
            object: nil,
            queue: .main
        ) { [weak self] note in
            if let tv = note.object as? UITextView {
                let type = tv.keyboardType
                let isNum = (type == .decimalPad || type == .numberPad || type == .phonePad || type == .asciiCapableNumberPad)
                Task { @MainActor in
                    self?.isNumpadActive = isNum
                    if isNum && tv.inputAccessoryView == nil {
                        tv.inputAccessoryView = Self.buildNumpadAccessoryView()
                        tv.reloadInputViews()
                    }
                }
            }
        }
        
        NotificationCenter.default.addObserver(
            forName: UIResponder.keyboardWillHideNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.isNumpadActive = false
            }
        }
    }
    
    @objc public static func buildNumpadAccessoryView() -> UIView {
        let screenWidth = UIScreen.main.bounds.width
        let bar = UIView(frame: CGRect(x: 0, y: 0, width: screenWidth, height: 46))
        bar.backgroundColor = UIColor(red: 0.10, green: 0.12, blue: 0.16, alpha: 0.96)
        
        let sep = UIView(frame: CGRect(x: 0, y: 0, width: screenWidth, height: 0.5))
        sep.backgroundColor = UIColor.white.withAlphaComponent(0.12)
        bar.addSubview(sep)
        
        let button = UIButton(type: .custom)
        button.frame = CGRect(x: screenWidth - 52, y: 4, width: 38, height: 38)
        button.layer.cornerRadius = 19
        button.clipsToBounds = true
        button.backgroundColor = UIColor(red: 0.0, green: 0.48, blue: 1.0, alpha: 1.0)
        
        let config = UIImage.SymbolConfiguration(pointSize: 18, weight: .bold)
        let checkmark = UIImage(systemName: "checkmark", withConfiguration: config)?.withTintColor(.white, renderingMode: .alwaysOriginal)
        button.setImage(checkmark, for: .normal)
        button.addTarget(self, action: #selector(dismissKeyboardAction), for: .touchUpInside)
        bar.addSubview(button)
        return bar
    }
    
    @objc public static func dismissKeyboardAction() {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}

/// Botón con diseño destacado y exclusivo de un check para cerrar el teclado numérico (Numpad)
public struct AppleNumpadDoneButton: View {
    public init() {}
    
    public var body: some View {
        Button {
            let generator = UIImpactFeedbackGenerator(style: .medium)
            generator.impactOccurred()
            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        } label: {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color(hex: "#007AFF"), Color(hex: "#005ECC")],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 38, height: 38)
                    .overlay(
                        Circle()
                            .stroke(Color.white.opacity(0.35), lineWidth: 1.0)
                    )
                    .shadow(color: Color(hex: "#007AFF").opacity(0.45), radius: 4, x: 0, y: 2)
                
                Image(systemName: "checkmark")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(Color.white)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Cerrar teclado numérico")
    }
}

public struct KeyboardDismissToolbarModifier: ViewModifier {
    @ObservedObject private var manager = NumpadKeyboardManager.shared
    
    public init() {}
    
    public func body(content: Content) -> some View {
        content
            .toolbar {
                if manager.isNumpadActive {
                    ToolbarItemGroup(placement: .keyboard) {
                        Spacer()
                        AppleNumpadDoneButton()
                    }
                }
            }
    }
}

public struct NumpadDismissToolbarModifier: ViewModifier {
    public init() {}
    
    public func body(content: Content) -> some View {
        content
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    AppleNumpadDoneButton()
                }
            }
    }
}

extension View {
    public func keyboardDismissArrow() -> some View {
        self.modifier(KeyboardDismissToolbarModifier())
    }
    
    public func keyboardDismissBlueCheck() -> some View {
        self.modifier(KeyboardDismissToolbarModifier())
    }
    
    public func numpadDismissDoneButton() -> some View {
        self.modifier(NumpadDismissToolbarModifier())
    }
}
