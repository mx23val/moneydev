import SwiftUI

public struct FloatingToastView: View {
    let toast: ExpenseViewModel.FloatingToastData
    var theme: AppColorTheme = .electricBlue
    let onDismiss: () -> Void
    
    @State private var dragOffset: CGFloat = 0
    
    public init(toast: ExpenseViewModel.FloatingToastData, theme: AppColorTheme = .electricBlue, onDismiss: @escaping () -> Void) {
        self.toast = toast
        self.theme = theme
        self.onDismiss = onDismiss
    }
    
    public var body: some View {
        let isBlack = theme == .electricBlack
        let accentColor: Color = toast.isSuccess ? (isBlack ? Color(hex: "#38BDF8") : theme.primary) : Color(hex: "#FF4D6D")
        
        HStack(spacing: 12) {
            // Ícono de estado con resplandor
            ZStack {
                Circle()
                    .fill(accentColor.opacity(isBlack ? 0.28 : 0.20))
                    .frame(width: 36, height: 36)
                
                Image(systemName: toast.isSuccess ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                    .font(.system(size: 19, weight: .bold))
                    .foregroundStyle(accentColor)
            }
            
            VStack(alignment: .leading, spacing: 3) {
                Text(toast.title)
                    .font(.system(size: 13, weight: .heavy, design: .rounded))
                    .foregroundStyle(Color.white)
                    .contrastTextOutline()
                    .lineLimit(1)
                
                Text(toast.message)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.95))
                    .contrastTextOutline()
                    .lineLimit(2)
            }
            
            Spacer()
            
            Button {
                onDismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Color.white.opacity(0.85))
                    .frame(width: 26, height: 26)
                    .background(Color.white.opacity(0.15))
                    .clipShape(Circle())
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(
                    LinearGradient(
                        colors: !toast.isSuccess ?
                            [Color(hex: "#2A0D15"), Color(hex: "#140508")] :
                            (isBlack ?
                                [Color(hex: "#1E293B"), Color(hex: "#0F172A")] :
                                [Color(hex: "#141A26"), Color(hex: "#0C101A")]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(
                    !toast.isSuccess ?
                        Color(hex: "#FF4D6D").opacity(0.8) :
                        (isBlack ? Color.white.opacity(0.40) : theme.primary.opacity(0.6)),
                    lineWidth: 1.2
                )
        )
        .shadow(color: Color.black.opacity(0.75), radius: 10, x: 0, y: 5)
        .shadow(color: accentColor.opacity(isBlack ? 0.35 : 0.25), radius: 8, x: 0, y: 2)
        .padding(.horizontal, 16)
        .offset(y: min(0, dragOffset))
        .gesture(
            DragGesture()
                .onChanged { value in
                    if value.translation.height < 0 {
                        dragOffset = value.translation.height
                    }
                }
                .onEnded { value in
                    if value.translation.height < -20 {
                        onDismiss()
                    } else {
                        withAnimation(.spring) {
                            dragOffset = 0
                        }
                    }
                }
        )
        .onAppear {
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(toast.isSuccess ? .success : .warning)
        }
    }
}
