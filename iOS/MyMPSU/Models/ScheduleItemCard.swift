//
//  ScheduleItemCard.swift
//  MyMPSU
//
//  Created by Nicolas Forest on 11/10/25.
//

import SwiftUI


#if os(iOS)
struct ScheduleItemCard: View {
    let item: ScheduleItem
    let homeworkButtonState: HomeworkButtonState
    let onAddHomework: (() -> Void)?
    @AppStorage("selectedThemeID") private var selectedThemeID = AppThemeCatalog.default

    init(item: ScheduleItem, homeworkButtonState: HomeworkButtonState = .hidden, onAddHomework: (() -> Void)? = nil) {
        self.item = item
        self.homeworkButtonState = homeworkButtonState
        self.onAddHomework = onAddHomework
    }

    private var activeTheme: AppTheme {
        AppThemeCatalog.theme(for: selectedThemeID)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if !item.period.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text(item.period)
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
            }
            HStack {
                Text(item.time)
                    .font(.title3)
                    .bold()
                Spacer()
                Text(item.subgroup ?? "")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            if let classURL = item.classURL, let url = URL(string: classURL) {
                Link(destination: url) {
                    Text(item.title)
                        .font(.title3)
                        .bold()
                        .underline()
                        .multilineTextAlignment(.leading)
                }
            } else {
                Text(item.title)
                    .font(.title3)
                    .bold()
                    .multilineTextAlignment(.leading)
            }
            HStack(spacing: 6) {
                Image(systemName: "pencil")
                Text(item.lessonType)
            }
            .font(.subheadline)
            if !item.teacher.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                HStack(spacing: 6) {
                    Image(systemName: "person.fill")
                    Text(item.teacher)
                }
                .font(.subheadline)
            }
            if !item.address.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                HStack(spacing: 6) {
                    Image(systemName: "mappin.and.ellipse")
                    Text(item.address)
                }
                .font(.footnote)
            }
            HStack(spacing: 8) {
                Text(item.room)
                    .font(.footnote)
                    .foregroundColor(.secondary)
                    .lineLimit(1)

                Spacer(minLength: 0)

                if homeworkButtonState != .hidden {
                    Button {
                        onAddHomework?()
                    } label: {
                        Label(homeworkButtonState.title, systemImage: homeworkButtonIcon)
                            .font(.caption.weight(.semibold))
                            .lineLimit(1)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(homeworkButtonFill)
                            .clipShape(Capsule())
                            .overlay(Capsule().stroke(cardStroke, lineWidth: 0.8))
                    }
                    .buttonStyle(.plain)
                    .disabled(!homeworkButtonState.isEnabled)
                    .opacity(homeworkButtonState.isEnabled ? 1 : 0.62)
                    .accessibilityLabel(homeworkButtonState.title)
                }
            }
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(cardStroke, lineWidth: 0.8)
        )
    }

    @ViewBuilder
    private var cardBackground: some View {
        if activeTheme.usesCloudSurface {
            activeTheme.cloudSurfaceFill
        } else {
            MyMPSUAdaptiveMaterialFill()
        }
    }

    private var cardStroke: Color {
        activeTheme.usesCloudSurface
        ? activeTheme.cloudSurfaceStroke
        : Color.white.opacity(0.22)
    }

    private var homeworkButtonFill: Color {
        activeTheme.usesCloudSurface
        ? activeTheme.cloudSurfaceFill
        : Color.mympsuHeaderCapsuleFill
    }

    private var homeworkButtonIcon: String {
        switch homeworkButtonState {
        case .add:
            return "plus.circle.fill"
        case .edit:
            return "pencil.circle.fill"
        case .view:
            return "doc.text.fill"
        case .unavailable, .hidden:
            return "doc.text"
        }
    }
}
#endif
