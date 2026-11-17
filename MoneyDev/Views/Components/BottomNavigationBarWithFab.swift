import SwiftUI

public struct BottomNavigationBarWithFab: View {
    @Bindable var viewModel: ExpenseViewModel
    @Binding var isFabExpanded: Bool
    let onAddExpenseClick: () -> Void
    let onAddIncomeClick: () -> Void
    let onVoiceClick: () -> Void
    let onSettingsClick: () -> Void

    private var activeTheme: AppColorTheme {
        AppColorTheme.fromId(viewModel.financialSummary.themeColorId)
    }

    /// Cinco segmentos visuales; el central queda reservado para el botón +.
    /// El selector sólo pinta la burbuja: los botones superpuestos gestionan los toques.
    private var navigationSegmentSelection: Binding<Int> {
        Binding(
            get: {
                switch viewModel.activeTab {
                case 0: return 0
                case 1: return 1
                case 2: return 3
                default: return 4
                }
            },
            set: { _ in }
        )
    }

    public init(
        viewModel: ExpenseViewModel,
        isFabExpanded: Binding<Bool>,
        onAddExpenseClick: @escaping () -> Void,
        onAddIncomeClick: @escaping () -> Void,
        onVoiceClick: @escaping () -> Void,
        onSettingsClick: @escaping () -> Void
    ) {
        self.viewModel = viewModel
        self._isFabExpanded = isFabExpanded
        self.onAddExpenseClick = onAddExpenseClick
        self.onAddIncomeClick = onAddIncomeClick
        self.onVoiceClick = onVoiceClick
        self.onSettingsClick = onSettingsClick
    }

    public var body: some View {
        ZStack(alignment: .bottom) {
            if isFabExpanded {
                Color.black.opacity(0.45)
                    .ignoresSafeArea()
                    .contentShape(Rectangle())
                    .onTapGesture {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                            isFabExpanded = false
                        }
                    }
                    .transition(.opacity)
            }

            VStack(spacing: 0) {
                if isFabExpanded {
                    fabExpandedBubbles
                        .frame(height: 10)
                        .zIndex(2)
                }

                dock
                    .frame(height: 60)
                    .padding(.horizontal, 16)
                    .padding(.bottom, -8)
            }
        }
        .ignoresSafeArea(.keyboard)
    }

    // MARK: - Dock compacto de cristal líquido
    private var dock: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let centerGap: CGFloat = 58
            let itemWidth = max((width - centerGap) / 4, 0)

            ZStack {
                // Mismo control nativo que el selector Dona / Barras. No se coloca
                // otra cápsula detrás: así existe una sola pista de cristal líquido.
                Picker("Navegación", selection: navigationSegmentSelection) {
                    Text(" ").tag(0)
                    Text(" ").tag(1)
                    Text(" ").tag(2)
                    Text(" ").tag(3)
                    Text(" ").tag(4)
                }
                .labelsHidden()
                .pickerStyle(.segmented)
                .tint(activeTheme.primary)
                .frame(maxWidth: .infinity)
                // Se conserva el selector nativo de Dona/Barras y únicamente se
                // amplía su renderizado vertical para que llene el dock compacto.
                .fixedSize(horizontal: false, vertical: true)
                .scaleEffect(x: 1, y: 1.55, anchor: .center)
                .frame(height: 56)
                .padding(.horizontal, 3)
                .clipShape(Capsule())
                .opacity(isFabExpanded ? 0.30 : 1.0)
                .allowsHitTesting(false)

                HStack(spacing: 0) {
                    navigationItem(index: 0, title: "Movimientos", icon: "list.bullet.rectangle.portrait.fill", itemWidth: itemWidth)
                    navigationItem(index: 1, title: "Estadísticas", icon: "chart.pie.fill", itemWidth: itemWidth)
                    Color.clear.frame(width: centerGap)
                    navigationItem(index: 2, title: "Modo PRO", icon: "crown.fill", itemWidth: itemWidth)
                    navigationItem(index: 3, title: "Ajustes", icon: "gearshape.fill", itemWidth: itemWidth)
                }
                .padding(.horizontal, 4)
                .opacity(isFabExpanded ? 0.30 : 1.0)
                .allowsHitTesting(!isFabExpanded)

                centerFabButton
                    .position(x: width / 2, y: proxy.size.height / 2)
                    .zIndex(10)
            }
        }
    }

    private func navigationItem(index: Int, title: String, icon: String, itemWidth: CGFloat) -> some View {
        let isSelected = viewModel.activeTab == index

        return Button {
            selectTab(index)
        } label: {
            VStack(spacing: 2) {
                Image(systemName: icon)
                    .font(.system(size: 15, weight: isSelected ? .bold : .medium))
                Text(title)
                    .font(.system(size: 9.5, weight: isSelected ? .bold : .medium))
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
            }
            .foregroundStyle(isSelected ? activeTheme.accentIconColor : AppColors.textSecondary.opacity(0.82))
            .frame(width: itemWidth, height: 52)
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private func selectTab(_ tab: Int) {
        guard tab != viewModel.activeTab else { return }
        triggerSelectionHaptic()
        viewModel.setActiveTab(tab)
    }

    // MARK: - Botón central
    private var centerFabButton: some View {
        Button {
            triggerHaptic()
            withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                isFabExpanded.toggle()
            }
        } label: {
            ZStack {
                Circle()
                    .fill(activeTheme.primary)
                    .frame(width: 46, height: 46)

                Image(systemName: "plus")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(isFabExpanded ? .white : activeTheme.onPrimaryText)
                    .rotationEffect(.degrees(isFabExpanded ? 45 : 0))
                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isFabExpanded)
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Acciones rápidas
    private var fabExpandedBubbles: some View {
        ZStack {
            bubbleButton(title: "Gasto", icon: "minus", color: AppColors.expenseRose, shadowColor: AppColors.expenseRose.opacity(0.38), offsetX: -84, offsetY: -42) {
                closeFabAndRun(onAddExpenseClick)
            }
            .transition(.asymmetric(insertion: .scale(scale: 0.2, anchor: .bottom).combined(with: .opacity), removal: .scale(scale: 0.2, anchor: .bottom).combined(with: .opacity)))

            bubbleButton(title: "Micrófono", icon: "mic.fill", color: activeTheme.primary, shadowColor: activeTheme.primary.opacity(0.38), offsetX: 0, offsetY: -96) {
                closeFabAndRun(onVoiceClick)
            }
            .transition(.asymmetric(insertion: .scale(scale: 0.2, anchor: .bottom).combined(with: .opacity), removal: .scale(scale: 0.2, anchor: .bottom).combined(with: .opacity)))

            bubbleButton(title: "Ingreso", icon: "plus", color: AppColors.incomeEmerald, shadowColor: AppColors.incomeEmerald.opacity(0.38), offsetX: 84, offsetY: -42) {
                closeFabAndRun(onAddIncomeClick)
            }
            .transition(.asymmetric(insertion: .scale(scale: 0.2, anchor: .bottom).combined(with: .opacity), removal: .scale(scale: 0.2, anchor: .bottom).combined(with: .opacity)))
        }
    }

    private func bubbleButton(title: String, icon: String, color: Color, shadowColor: Color, offsetX: CGFloat, offsetY: CGFloat, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 4) {
                ZStack {
                    Circle()
                        .fill(color)
                        .frame(width: 50, height: 50)
                        .shadow(color: shadowColor, radius: 8, x: 0, y: 4)

                    Image(systemName: icon)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(.white)
                }

                Text(title)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(AppColors.textPrimary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(activeTheme.interfaceSurface.opacity(0.95))
                    .clipShape(Capsule())
            }
        }
        .buttonStyle(.plain)
        .offset(x: offsetX, y: offsetY)
    }

    private func closeFabAndRun(_ action: @escaping () -> Void) {
        triggerHaptic()
        withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
            isFabExpanded = false
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            action()
        }
    }

    private func triggerHaptic() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    private func triggerSelectionHaptic() {
        UISelectionFeedbackGenerator().selectionChanged()
    }
}
