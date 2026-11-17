import SwiftUI

public struct CreateCategoryDialog: View {
    let theme: AppColorTheme
    let selectedType: TransactionType
    let onCreated: (CategoryItem) -> Void
    let onDismiss: () -> Void
    
    @State private var name: String = ""
    @State private var errorMessage: String? = nil
    @State private var showLimitAlert: Bool = false
    
    private var hasValidName: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    public init(
        theme: AppColorTheme,
        selectedType: TransactionType,
        onCreated: @escaping (CategoryItem) -> Void,
        onDismiss: @escaping () -> Void
    ) {
        self.theme = theme
        self.selectedType = selectedType
        self.onCreated = onCreated
        self.onDismiss = onDismiss
    }
    
    public var body: some View {
        NavigationStack {
            ZStack {
                ThemedModalBackground(theme: theme)
                
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {
                        // Icono flotante con alto contraste
                        ZStack {
                            Circle()
                                .fill(theme == .electricBlack ? Color.white.opacity(0.18) : theme.primary.opacity(0.25))
                                .frame(width: 54, height: 54)
                            
                            Image(systemName: "folder.badge.plus")
                                .font(.system(size: 24, weight: .bold))
                                .foregroundStyle(theme == .electricBlack ? Color.white : theme.accentIconColor)
                        }
                        .padding(.top, 12)
                        
                        // Títulos en español y con contraste nítido
                        VStack(spacing: 5) {
                            Text("Nueva Categoría")
                                .font(.system(size: 20, weight: .black, design: .rounded))
                                .foregroundStyle(Color.white)
                                .contrastTextOutline()
                            
                            Text("para movimientos de tipo \(selectedType == .income ? "ingreso" : "gasto")")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(Color.white.opacity(0.85))
                                .contrastTextOutline()
                        }
                        
                        // Campo de entrada con sombreado, sin bordes y límite de 25 caracteres
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Nombre de la categoría")
                                .font(.system(size: 13, weight: .bold, design: .rounded))
                                .foregroundStyle(theme == .electricBlack ? Color.white : theme.accentTextColor)
                                .contrastTextOutline()
                            
                            TextField(
                                "Ej: Cursos, Freelance, Cine...",
                                text: $name,
                                prompt: Text("Ej: Cursos, Freelance, Cine...").foregroundStyle(Color.white.opacity(0.45))
                            )
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(Color.white)
                            .contrastTextOutline()
                            .submitLabel(.done)
                            .onSubmit {
                                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                            }
                            .padding(14)
                            .background(
                                ThemedCardBackgroundView(theme: theme, cornerRadius: 14)
                            )
                            .onChange(of: name) { oldValue, newValue in
                                if newValue.count > 25 {
                                    name = String(newValue.prefix(25))
                                    showLimitAlert = true
                                    let generator = UINotificationFeedbackGenerator()
                                    generator.notificationOccurred(.warning)
                                } else if newValue.count == 25 && oldValue.count < 25 {
                                    showLimitAlert = true
                                    let generator = UINotificationFeedbackGenerator()
                                    generator.notificationOccurred(.warning)
                                }
                                if errorMessage != nil {
                                    errorMessage = nil
                                }
                            }
                            
                            // Contador y aviso de límite
                            HStack {
                                if let err = errorMessage {
                                    HStack(spacing: 4) {
                                        Image(systemName: "exclamationmark.triangle.fill")
                                            .font(.system(size: 11, weight: .bold))
                                        Text(err)
                                            .font(.system(size: 11, weight: .bold))
                                    }
                                    .foregroundStyle(Color(hex: "#FF6B81"))
                                    .contrastTextOutline()
                                } else if name.count >= 25 {
                                    HStack(spacing: 4) {
                                        Image(systemName: "info.circle.fill")
                                            .font(.system(size: 11, weight: .bold))
                                        Text("Límite de 25 caracteres alcanzado")
                                            .font(.system(size: 11, weight: .bold))
                                    }
                                    .foregroundStyle(Color(hex: "#F59E0B"))
                                    .contrastTextOutline()
                                }
                                
                                Spacer()
                                
                                Text("\(name.count)/25")
                                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                                    .foregroundStyle(name.count >= 25 ? Color(hex: "#F59E0B") : Color.white.opacity(0.6))
                                    .contrastTextOutline()
                            }
                            .padding(.horizontal, 4)
                        }
                        
                                         // Botón de acción principal
                        VStack(spacing: 10) {
                            Button {
                                handleSave()
                            } label: {
                                HStack(spacing: 8) {
                                    if hasValidName {
                                        Image(systemName: "checkmark.circle.fill")
                                            .font(.system(size: 16, weight: .bold))
                                    }
                                    
                                    Text("Guardar Categoría")
                                        .font(.system(size: 15, weight: hasValidName ? .black : .bold, design: .rounded))
                                }
                                .foregroundStyle(hasValidName ? Color.white : Color.white.opacity(0.35))
                                .contrastTextOutline(radius: hasValidName ? 0.8 : 0.4)
                                .frame(maxWidth: .infinity)
                                .frame(height: 48)
                                .background(
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .fill(
                                            hasValidName ?
                                                (theme == .electricBlack ?
                                                    LinearGradient(colors: [Color(hex: "#38BDF8"), Color(hex: "#1D4ED8")], startPoint: .leading, endPoint: .trailing) :
                                                    LinearGradient(colors: theme.gradient, startPoint: .leading, endPoint: .trailing)
                                                ) :
                                                LinearGradient(
                                                    colors: [Color(hex: "#151822"), Color(hex: "#0F1118")],
                                                    startPoint: .topLeading,
                                                    endPoint: .bottomTrailing
                                                )
                                        )
                                )
                                .shadow(
                                    color: hasValidName ?
                                        (theme == .electricBlack ? Color(hex: "#38BDF8") : theme.primary).opacity(0.70) :
                                        Color.clear,
                                    radius: hasValidName ? 14 : 0,
                                    x: 0,
                                    y: 3
                                )
                                .shadow(
                                    color: hasValidName ?
                                        (theme == .electricBlack ? Color(hex: "#38BDF8") : theme.primary).opacity(0.40) :
                                        Color.clear,
                                    radius: hasValidName ? 6 : 0,
                                    x: 0,
                                    y: 1
                                )
                                .shadow(
                                    color: Color.black.opacity(hasValidName ? 0.45 : 0.25),
                                    radius: 6,
                                    x: 0,
                                    y: 2
                                )
                                .scaleEffect(hasValidName ? 1.015 : 1.0)
                                .animation(.spring(response: 0.35, dampingFraction: 0.72), value: hasValidName)
                            }
                            .buttonStyle(.plain)
                            
                            Button {
                                onDismiss()
                            } label: {
                                Text("Cancelar")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundStyle(Color.white.opacity(0.75))
                                    .contrastTextOutline()
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 42)
                                    .background(
                                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                                            .fill(Color.white.opacity(0.10))
                                    )
                                    .shadow(color: Color.black.opacity(0.20), radius: 3, x: 0, y: 1)
                            }
                        }
                        .padding(.top, 6)
                    }
                    .padding(20)
                    .frame(maxWidth: .infinity)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Nueva Categoría")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(Color.white)
                        .contrastTextOutline()
                }
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancelar") {
                        onDismiss()
                    }
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color.white)
                    .contrastTextOutline()
                }
            }
            .alert("Límite alcanzado", isPresented: $showLimitAlert) {
                Button("Entendido", role: .cancel) { }
            } message: {
                Text("El nombre de la categoría no puede superar los 25 caracteres.")
            }
        }
        .preferredColorScheme(.dark)
        .presentationDetents([.fraction(0.65), .large])
        .presentationDragIndicator(.visible)
        .themedSheetContainer(theme: theme)
        .keyboardDismissBlueCheck()
        .ignoresSafeArea(.container, edges: .bottom)
    }
    
    private func handleSave() {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            errorMessage = "Ingresa un nombre para la categoría."
            return
        }
        
        let allExisting = CategoryHelper.allCategories(for: selectedType)
        if allExisting.contains(where: {
            $0.name.caseInsensitiveCompare(trimmed) == .orderedSame ||
            CategoryHelper.normalize($0.name) == CategoryHelper.normalize(trimmed)
        }) || CategoryHelper.isForbiddenOrPredefinedCategory(name: trimmed, type: selectedType) {
            errorMessage = "Ya existe una categoría predefinida para este concepto."
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.warning)
            return
        }
        
        let created = CategoryHelper.addCustomCategory(
            name: trimmed,
            type: selectedType
        )
        
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
        
        onCreated(created)
    }
}
