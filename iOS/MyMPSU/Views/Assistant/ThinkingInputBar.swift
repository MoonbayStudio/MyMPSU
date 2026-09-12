import SwiftUI

struct ThinkingInputBar: View {
    @Binding var text: String
    let isThinking: Bool
    var isCancelling = false
    let placeholder: String
    var thinkingPlaceholder: String? = nil
    let sendSymbolName: String
    var isDisabled = false
    let onSend: () -> Void
    let onCancel: () -> Void
    let themedShape: ThemedComponentShape

    @ViewBuilder
    var body: some View {
        #if os(macOS)
        if #available(macOS 12.0, *) {
            animatedInputContent
        } else {
            inputContent(phase: 0)
        }
        #else
        animatedInputContent
        #endif
    }

    @available(macOS 12.0, *)
    private var animatedInputContent: some View {
        TimelineView(.animation) { timeline in
            inputContent(phase: animationPhase(for: timeline.date))
        }
    }

    private func inputContent(phase: Double) -> some View {
        inputShape
            .fill(Color.mympsuHeaderCapsuleFill.opacity(0.92))
            .frame(height: 54)
            .overlay(inputControls)
            .clipShape(inputShape)
            .background(inputGlow(phase: phase))
            .overlay(
                inputShape
                    .stroke(rainbowGradient(phase: phase), lineWidth: isThinking ? 1.8 : 0.9)
                    .opacity(isDisabled ? 0.25 : (isThinking ? 1 : 0.58))
            )
            .overlay(
                inputShape
                    .stroke(Color.white.opacity(isThinking ? 0.22 : 0.10), lineWidth: 0.8)
            )
            .shadow(color: Color.blue.opacity(isThinking ? 0.26 : 0.16), radius: isThinking ? 14 : 9, x: 0, y: 0)
            .shadow(color: Color.orange.opacity(isThinking ? 0.22 : 0.12), radius: isThinking ? 16 : 10, x: 0, y: 2)
            .animation(.easeInOut(duration: 0.18), value: isThinking)
    }

    private var inputControls: some View {
        HStack(spacing: 10) {
            ZStack(alignment: .leading) {
                if text.isEmpty {
                    Text(displayedPlaceholder)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                        .id(displayedPlaceholder)
                }

                TextField("", text: $text)
                    .textFieldStyle(.plain)
                    .disabled(isDisabled || isThinking)
                    .thinkingInputSubmit {
                        submit()
                    }
            }
            .animation(.easeInOut(duration: 0.22), value: displayedPlaceholder)

            Button {
                isThinking ? onCancel() : submit()
            } label: {
                sendButtonContent
                    .frame(width: 34, height: 34)
                    .background(sendButtonBackground)
                    .clipShape(Circle())
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .disabled(isDisabled || (!isThinking && text.mympsuTrimmed.isEmpty))
            .opacity(isDisabled || (!isThinking && text.mympsuTrimmed.isEmpty) ? 0.5 : 1)
        }
        .padding(.leading, 14)
        .padding(.trailing, 8)
        .padding(.vertical, 8)
        .background(Color.clear)
    }

    private func inputGlow(phase: Double) -> some View {
        inputShape
            .fill(rainbowGradient(phase: phase))
            .blur(radius: 11)
            .opacity(isDisabled ? 0.22 : 0.62)
            .padding(.horizontal, 3)
            .padding(.vertical, 2)
    }

    @ViewBuilder
    private var sendButtonContent: some View {
        if isThinking && !isCancelling {
            ProgressView()
                .controlSize(.small)
        } else {
            Image(systemName: isThinking ? "xmark" : sendSymbolName)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.white)
        }
    }

    @ViewBuilder
    private var sendButtonBackground: some View {
        if isThinking {
            Color.red.opacity(0.88)
        } else {
            LinearGradient(
                colors: [Color.blue, Color.purple, Color.pink],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    private var inputShape: DynamicThemeShape {
        DynamicThemeShape(themedShape: themedShape)
    }

    private var displayedPlaceholder: String {
        if isThinking, let thinkingPlaceholder {
            return thinkingPlaceholder
        }

        return placeholder
    }

    private func rainbowGradient(phase: Double) -> AngularGradient {
        AngularGradient(
            gradient: Gradient(colors: [
                Color.pink,
                Color.orange,
                Color.yellow,
                Color.green,
                Color(red: 0.0, green: 0.78, blue: 0.9),
                Color.blue,
                Color.purple,
                Color.pink
            ]),
            center: .center,
            startAngle: .degrees(phase),
            endAngle: .degrees(phase + 360)
        )
    }

    private func animationPhase(for date: Date) -> Double {
        guard isThinking else { return 0 }
        return date.timeIntervalSinceReferenceDate
            .truncatingRemainder(dividingBy: 1.6) / 1.6 * 360
    }

    private func submit() {
        guard !text.mympsuTrimmed.isEmpty, !isThinking, !isDisabled else { return }
        onSend()
    }
}

private struct ThinkingInputSubmitModifier: ViewModifier {
    let action: () -> Void

    @ViewBuilder
    func body(content: Content) -> some View {
#if os(macOS)
        if #available(macOS 12.0, *) {
            content
                .submitLabel(.send)
                .onSubmit(action)
        } else {
            content
        }
#else
        content
            .submitLabel(.send)
            .onSubmit(action)
#endif
    }
}

private extension View {
    func thinkingInputSubmit(_ action: @escaping () -> Void) -> some View {
        modifier(ThinkingInputSubmitModifier(action: action))
    }
}
