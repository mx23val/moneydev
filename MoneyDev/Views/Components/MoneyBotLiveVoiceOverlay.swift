import SwiftUI
import AVFoundation
import UIKit

/// Vista de UI del modo Live Voice de MoneyBot.
/// Esta vista es SOLO presentación — toda la lógica de conversación vive en
/// MoneyBotLiveVoiceController.shared, que es un singleton que sobrevive
/// a los cambios de ciclo de vida de la vista (background, pantalla bloqueada, etc.)
public struct MoneyBotLiveVoiceOverlay: View {
    @Bindable var viewModel: ExpenseViewModel
    public var selectedWalletScopeId: Int64?
    public var selectedWalletScopeName: String
    public var onClose: () -> Void
    public var onOpenChat: (() -> Void)? = nil
    
    // El controlador es el singleton que mantiene toda la lógica viva en background
    @State private var controller = MoneyBotLiveVoiceController.shared
    @State private var speechService = SpeechRecognitionService.shared
    
    public init(
        viewModel: ExpenseViewModel,
        selectedWalletScopeId: Int64?,
        selectedWalletScopeName: String,
        onClose: @escaping () -> Void,
        onOpenChat: (() -> Void)? = nil
    ) {
        self.viewModel = viewModel
        self.selectedWalletScopeId = selectedWalletScopeId
        self.selectedWalletScopeName = selectedWalletScopeName
        self.onClose = onClose
        self.onOpenChat = onOpenChat
    }
    
    public var body: some View {
        ZStack {
            // Fondo dinámico inmersivo ultra oscuro
            ThemedModalBackground(theme: viewModel.activeTheme)
            
            // Gradiente ambiental suave que expande la luminosidad del orbe por toda la pantalla
            RadialGradient(
                colors: [
                    viewModel.activeTheme.primary.opacity(controller.orbState == .speaking ? 0.28 : 0.16),
                    viewModel.activeTheme.primary.opacity(0.06),
                    Color.black.opacity(0.92),
                    Color.black
                ],
                center: .center,
                startRadius: 70,
                endRadius: 650
            )
            .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Top Header Bar
                HStack {
                    // Botón Cerrar / Finalizar sesión de voz
                    Button {
                        handleClose()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "xmark")
                                .font(.system(size: 13, weight: .bold))
                            Text("Cerrar")
                                .font(.system(size: 14, weight: .bold))
                        }
                        .foregroundStyle(Color.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(
                            Capsule()
                                .fill(Color.white.opacity(0.12))
                        )
                        .overlay(
                            Capsule()
                                .stroke(Color.white.opacity(0.20), lineWidth: 1)
                        )
                    }
                    
                    Spacer()
                    
                    // Badge Live con indicador pulsante
                    HStack(spacing: 6) {
                        Circle()
                            .fill(Color(hex: "#10B981"))
                            .frame(width: 8, height: 8)
                            .shadow(color: Color(hex: "#10B981").opacity(0.8), radius: 4)
                        
                        Text("MoneyBot Live")
                            .font(.system(size: 13, weight: .black, design: .rounded))
                            .foregroundStyle(Color.white)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(Color.black.opacity(0.40))
                    )
                    .overlay(
                        Capsule()
                            .stroke(viewModel.activeTheme.primary.opacity(0.35), lineWidth: 1)
                    )
                    
                    Spacer()
                    
                    // Indicador de Billetera activa
                    HStack(spacing: 4) {
                        Image(systemName: "wallet.pass.fill")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(viewModel.activeTheme.primary)
                        Text(selectedWalletScopeName)
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(Color.white.opacity(0.85))
                            .lineLimit(1)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(Color.white.opacity(0.08))
                    )
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                
                Spacer()
                
                // Zona Central: Orbe Flotante Inteligente con interacción directa
                VStack(spacing: 22) {
                    Button {
                        controller.handleOrbTapped()
                    } label: {
                        MoneyBotLiveVoiceOrbView(
                            state: controller.orbState,
                            theme: viewModel.activeTheme
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Orbe interactivo de MoneyBot")
                    
                    VStack(spacing: 12) {
                        // Estado textual del Asistente
                        Text(controller.statusTitle)
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                            .foregroundStyle(Color.white)
                            .shadow(color: Color.black.opacity(0.5), radius: 4)
                            .animation(.easeInOut(duration: 0.2), value: controller.statusTitle)
                        
                        // Transcripción en vivo exclusiva del usuario
                        transcriptionCard
                    }
                    .frame(minHeight: 64)
                }
                
                Spacer()
                
                // Controles Inferiores (Micrófono, Selector de Voz, Volver al Chat)
                HStack(spacing: 16) {
                    // Botón Silenciar / Desilenciar Micrófono
                    Button {
                        controller.toggleMute()
                    } label: {
                        ZStack {
                            Circle()
                                .fill(controller.isMicMuted ? Color(hex: "#EF4444") : Color.white.opacity(0.12))
                                .frame(width: 52, height: 52)
                                .overlay(
                                    Circle()
                                        .stroke(Color.white.opacity(0.25), lineWidth: 1)
                                    )
                            
                            Image(systemName: controller.isMicMuted ? "mic.slash.fill" : "mic.fill")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundStyle(Color.white)
                        }
                    }
                    .accessibilityLabel(controller.isMicMuted ? "Reanudar micrófono" : "Silenciar micrófono")
                    
                    // Botón Selector de Voz ElevenLabs
                    Menu {
                        Section("Voz de MoneyBot") {
                            ForEach(ElevenLabsVoiceOption.allCases) { voice in
                                Button {
                                    controller.previewAndSelectElevenLabsVoice(voice)
                                } label: {
                                    HStack {
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(voice.displayName)
                                                .font(.system(size: 15, weight: .semibold))
                                            Text(voice.tag)
                                                .font(.system(size: 12))
                                                .foregroundStyle(.secondary)
                                        }
                                        Spacer()
                                        if ElevenLabsService.shared.selectedVoice == voice {
                                            Image(systemName: "checkmark")
                                                .font(.system(size: 13, weight: .bold))
                                                .foregroundStyle(.blue)
                                        }
                                    }
                                }
                            }
                        }
                    } label: {
                        ZStack {
                            Circle()
                                .fill(Color.white.opacity(0.12))
                                .frame(width: 52, height: 52)
                                .overlay(
                                    Circle()
                                        .stroke(Color.white.opacity(0.25), lineWidth: 1)
                                )
                            
                            Image(systemName: "person.wave.2.fill")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundStyle(Color.white)
                        }
                    }
                    .accessibilityLabel("Cambiar voz de MoneyBot")
                    
                    // Botón Ver Chat
                    Button {
                        if let onOpenChat = onOpenChat {
                            onOpenChat()
                        } else {
                            handleClose()
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                                viewModel.openVoiceAssistant()
                            }
                        }
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "bubble.left.and.text.bubble.right.fill")
                                .font(.system(size: 14, weight: .bold))
                            Text("Ver Chat")
                                .font(.system(size: 14, weight: .bold))
                        }
                        .foregroundStyle(Color.black)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 14)
                        .background(
                            Capsule()
                                .fill(viewModel.activeTheme == .electricBlack ? Color.white : viewModel.activeTheme.primary)
                        )
                        .shadow(
                            color: (viewModel.activeTheme == .electricBlack ? Color.white : viewModel.activeTheme.primary).opacity(0.35),
                            radius: 8, x: 0, y: 3
                        )
                    }
                }
                .padding(.bottom, 36)
            }
        }
        .onAppear {
            UIApplication.shared.isIdleTimerDisabled = true
            // Iniciar sesión en el controlador singleton si aún no está activo
            if !controller.isSessionActive {
                Task { @MainActor in
                    await controller.startSession(
                        viewModel: viewModel,
                        walletId: selectedWalletScopeId,
                        walletName: selectedWalletScopeName
                    )
                }
            } else {
                // La sesión ya estaba corriendo en background — solo actualizar la referencia al viewModel
                controller.viewModel = viewModel
            }
        }
        .onDisappear {
            // CRÍTICO: NO terminar la sesión cuando la view desaparece.
            // La vista desaparece cuando:
            //   1. El usuario cierra el overlay manualmente (ya llamó handleClose que termina la sesión)
            //   2. La app va a background / pantalla bloqueada (debemos CONTINUAR la sesión)
            // Por tanto, nunca llamar endSession() aquí.
            // El controlador singleton mantiene todo activo.
            UIApplication.shared.isIdleTimerDisabled = controller.isSessionActive
        }
    }
    
    // MARK: - Tarjeta de Transcripción del Usuario
    @ViewBuilder
    private var transcriptionCard: some View {
        if speechService.permissionDenied {
            Button {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                    Text("Activar permisos en Ajustes")
                }
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(Color(hex: "#F59E0B"))
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(Capsule().fill(Color.black.opacity(0.6)))
                .overlay(Capsule().stroke(Color(hex: "#F59E0B").opacity(0.4), lineWidth: 1))
            }
        } else {
            switch controller.orbState {
            case .listening:
                let currentSpeech = speechService.transcribedText.trimmingCharacters(in: .whitespacesAndNewlines)
                if !currentSpeech.isEmpty {
                    HStack(spacing: 8) {
                        Image(systemName: "mic.fill")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(viewModel.activeTheme.primary)
                        
                        Text("\u{201C}\(currentSpeech)\u{201D}")
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                            .foregroundStyle(Color.white)
                            .multilineTextAlignment(.center)
                            .lineLimit(3)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(
                        Capsule()
                            .fill(Color.black.opacity(0.55))
                    )
                    .overlay(
                        Capsule()
                            .stroke(viewModel.activeTheme.primary.opacity(0.50), lineWidth: 1)
                    )
                    .shadow(color: viewModel.activeTheme.primary.opacity(0.25), radius: 8)
                    .transition(.opacity)
                } else {
                    HStack(spacing: 6) {
                        Image(systemName: "waveform")
                            .font(.system(size: 12))
                        Text("Habla ahora, te estoy escuchando...")
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                    }
                    .foregroundStyle(Color.white.opacity(0.60))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(Color.white.opacity(0.06)))
                    .transition(.opacity)
                }
                
            case .thinking:
                if !controller.lastUserSpeech.isEmpty {
                    HStack(spacing: 8) {
                        ProgressView()
                            .tint(.white)
                            .scaleEffect(0.75)
                        
                        Text("\u{201C}\(controller.lastUserSpeech)\u{201D}")
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                            .foregroundStyle(Color.white.opacity(0.95))
                            .lineLimit(2)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Capsule().fill(Color.black.opacity(0.50)))
                    .overlay(Capsule().stroke(Color.white.opacity(0.15), lineWidth: 1))
                    .transition(.opacity)
                }
                
            case .speaking:
                HStack(spacing: 6) {
                    Image(systemName: "speaker.wave.2.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(viewModel.activeTheme.primary)
                    Text("MoneyBot hablando...")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(Color.white.opacity(0.75))
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .background(Capsule().fill(Color.white.opacity(0.06)))
                .transition(.opacity)
            }
        }
    }
    
    // MARK: - Acción de Cierre
    private func handleClose() {
        UIApplication.shared.isIdleTimerDisabled = false
        // Terminar la sesión en el controlador (detiene mic, TTS, Live Activity, etc.)
        controller.endSession()
        onClose()
    }
}
