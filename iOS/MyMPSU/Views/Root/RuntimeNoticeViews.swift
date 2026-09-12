import SwiftUI

struct RuntimeNoticeBanner: View {
    let notice: SystemNotice
    let onDismiss: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: symbolName)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(tint)
                .frame(width: 24, height: 24)

            VStack(alignment: .leading, spacing: 4) {
                Text(notice.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.primary)
                Text(notice.message)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)

            if notice.dismissible {
                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.secondary)
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Скрыть уведомление")
            }
        }
        .padding(12)
        .background(tint.opacity(0.14))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(tint.opacity(0.35), lineWidth: 0.8)
        )
        .shadow(color: Color.black.opacity(0.10), radius: 14, x: 0, y: 8)
    }

    private var symbolName: String {
        switch notice.type {
        case .info: return "info.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .maintenance: return "wrench.and.screwdriver.fill"
        case .critical: return "exclamationmark.octagon.fill"
        }
    }

    private var tint: Color {
        switch notice.type {
        case .info: return .accentColor
        case .warning: return Color(red: 0.90, green: 0.58, blue: 0.18)
        case .maintenance: return Color(red: 0.40, green: 0.58, blue: 0.95)
        case .critical: return .red
        }
    }
}

struct RuntimeNoticeModalContent: View {
    let notice: SystemNotice
    let onDismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: symbolName)
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundColor(tint)
                    .frame(width: 34, height: 34)

                VStack(alignment: .leading, spacing: 5) {
                    Text(notice.title)
                        .font(.headline)
                    Text(notice.type.title)
                        .font(.caption.weight(.semibold))
                        .foregroundColor(tint)
                }

                Spacer(minLength: 0)
            }

            Text(notice.message)
                .font(.body)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            if notice.dismissible {
                Button("Понятно", action: onDismiss)
                    .buttonStyle(.plain)
                    .mympsuDefaultSurface(cornerRadius: 14, padding: 10)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
        .padding(20)
    }

    private var symbolName: String {
        switch notice.type {
        case .info: return "info.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .maintenance: return "wrench.and.screwdriver.fill"
        case .critical: return "exclamationmark.octagon.fill"
        }
    }

    private var tint: Color {
        switch notice.type {
        case .info: return .accentColor
        case .warning: return Color(red: 0.90, green: 0.58, blue: 0.18)
        case .maintenance: return Color(red: 0.40, green: 0.58, blue: 0.95)
        case .critical: return .red
        }
    }
}
