import SwiftUI

public struct PeriodOptionItem<T: Hashable & Sendable>: Identifiable, Sendable {
    public var id: String { title }
    public let value: T
    public let title: String
    public let subtitle: String
    public let iconSymbol: String
    public let isCustomFilter: Bool
    
    public init(
        value: T,
        title: String,
        subtitle: String,
        iconSymbol: String,
        isCustomFilter: Bool = false
    ) {
        self.value = value
        self.title = title
        self.subtitle = subtitle
        self.iconSymbol = iconSymbol
        self.isCustomFilter = isCustomFilter
    }
}

public struct PeriodSelectorDialog<T: Hashable & Sendable>: View {
    let title: String
    let options: [PeriodOptionItem<T>]
    let selectedOption: T
    let onSelectOption: (T) -> Void
    let onSelectCustomRange: (() -> Void)?
    let onDismiss: () -> Void
    
    public init(
        title: String = "Seleccionar Período",
        options: [PeriodOptionItem<T>],
        selectedOption: T,
        onSelectOption: @escaping (T) -> Void,
        onSelectCustomRange: (() -> Void)? = nil,
        onDismiss: @escaping () -> Void
    ) {
        self.title = title
        self.options = options
        self.selectedOption = selectedOption
        self.onSelectOption = onSelectOption
        self.onSelectCustomRange = onSelectCustomRange
        self.onDismiss = onDismiss
    }
    
    public var body: some View {
        NavigationStack {
            ZStack {
                AppColors.midnightBlack.ignoresSafeArea()
                
                VStack(spacing: 12) {
                    ScrollView {
                        VStack(spacing: 10) {
                            ForEach(options) { item in
                                let isSelected = item.value == selectedOption
                                
                                Button {
                                    if item.isCustomFilter {
                                        onDismiss()
                                        onSelectCustomRange?()
                                    } else {
                                        onSelectOption(item.value)
                                        onDismiss()
                                    }
                                } label: {
                                    HStack(spacing: 14) {
                                        Circle()
                                            .fill(isSelected ? Color(hex: "#38BDF8").opacity(0.2) : AppColors.navySurfaceVariant)
                                            .frame(width: 40, height: 40)
                                            .overlay {
                                                Image(systemName: item.iconSymbol)
                                                    .font(.system(size: 16, weight: .bold))
                                                    .foregroundStyle(isSelected ? Color(hex: "#38BDF8") : AppColors.textSecondary)
                                            }
                                        
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(item.title)
                                                .font(.system(size: 15, weight: isSelected ? .bold : .medium))
                                                .foregroundStyle(isSelected ? .white : AppColors.textPrimary)
                                            
                                            Text(item.subtitle)
                                                .font(.system(size: 12))
                                                .foregroundStyle(AppColors.textSecondary)
                                        }
                                        
                                        Spacer()
                                        
                                        if isSelected {
                                            Image(systemName: "checkmark.circle.fill")
                                                .font(.system(size: 18))
                                                .foregroundStyle(Color(hex: "#38BDF8"))
                                        }
                                    }
                                    .padding(14)
                                    .background(isSelected ? AppColors.darkNavySurface : AppColors.darkNavySurface.opacity(0.6))
                                    .clipShape(RoundedRectangle(cornerRadius: 14))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 14)
                                            .stroke(isSelected ? Color(hex: "#38BDF8").opacity(0.6) : AppColors.cardBorderNavy, lineWidth: 1)
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(16)
                    }
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cerrar", action: onDismiss)
                        .foregroundStyle(AppColors.textSecondary)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}
