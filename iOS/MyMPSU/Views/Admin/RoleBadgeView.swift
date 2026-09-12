import SwiftUI

struct RoleBadgeView: View {
    let role: UserRole

    private var symbolName: String {
        switch role.type {
        case "admin":
            return "crown.fill"
        case "moderator":
            return "shield.lefthalf.filled"
        case "group_leader":
            return "star.fill"
        case "tester":
            return "testtube.2"
        case "premium":
            return "sparkles"
        case "plus":
            return "plus.circle.fill"
        case "free":
            return "circle"
        case "student":
            return "person.fill"
        case "group":
            return "person.3.fill"
        default:
            return "tag.fill"
        }
    }

    private var tint: Color {
        switch role.type {
        case "admin":
            return Color(red: 0.95, green: 0.68, blue: 0.28)
        case "moderator":
            return Color(red: 0.63, green: 0.56, blue: 0.86)
        case "group_leader":
            return Color(red: 0.38, green: 0.66, blue: 0.95)
        case "tester":
            return Color(red: 0.42, green: 0.72, blue: 0.96)
        case "premium":
            return Color(red: 0.88, green: 0.55, blue: 0.93)
        case "plus":
            return Color(red: 0.34, green: 0.72, blue: 0.76)
        case "free":
            return Color.secondary
        case "student":
            return Color(red: 0.44, green: 0.72, blue: 0.50)
        case "group":
            return Color(red: 0.34, green: 0.62, blue: 0.86)
        default:
            return Color.secondary
        }
    }

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: symbolName)
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(tint)

            Text(role.title)
                .font(.caption2.weight(.semibold))
                .foregroundColor(.primary)
                .lineLimit(1)
        }
        .fixedSize(horizontal: true, vertical: false)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(badgeBackground)
        .clipShape(Capsule())
        .overlay(
            Capsule().stroke(tint.opacity(0.28), lineWidth: 0.8)
        )
        .mympsuGlass(in: Capsule())
        .accessibilityElement(children: .combine)
        .accessibilityLabel(role.title)
    }

    @ViewBuilder
    private var badgeBackground: some View {
#if os(iOS)
        if #available(iOS 15.0, *) {
            tint.opacity(0.12).background(.ultraThinMaterial)
        } else {
            tint.opacity(0.14)
        }
#elseif os(macOS)
        if #available(macOS 12.0, *) {
            tint.opacity(0.12).background(.ultraThinMaterial)
        } else {
            tint.opacity(0.14)
        }
#else
        tint.opacity(0.14)
#endif
    }
}

struct RoleBadgeStackView: View {
    let roles: [UserRole]

    private var sortedRoles: [UserRole] {
        roles.sorted { lhs, rhs in
            let lhsPriority = UserRole.roleOrder[lhs.type] ?? 999
            let rhsPriority = UserRole.roleOrder[rhs.type] ?? 999
            if lhsPriority != rhsPriority {
                return lhsPriority < rhsPriority
            }
            return lhs.title.localizedStandardCompare(rhs.title) == .orderedAscending
        }
    }

    var body: some View {
        if !sortedRoles.isEmpty {
            if #available(iOS 16.0, macOS 13.0, *) {
                RoleBadgeFlowLayout(horizontalSpacing: 6, verticalSpacing: 6) {
                    ForEach(sortedRoles) { role in
                        RoleBadgeView(role: role)
                    }
                }
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(sortedRoles) { role in
                        RoleBadgeView(role: role)
                    }
                }
            }
        }
    }
}

struct UserBadgeIconView: View {
    let badge: UserBadge
    var size: CGFloat = 18

    var body: some View {
        Image(badge.iconName)
            .resizable()
            .interpolation(.high)
            .scaledToFit()
            .frame(width: size, height: size)
            .accessibilityHidden(true)
    }
}

struct UserBadgeInlineStackView: View {
    let badges: [UserBadge]
    var limit = 3
    var iconSize: CGFloat = 18

    @State private var selectedBadge: UserBadge?

    private var visibleBadges: [UserBadge] {
        Array(UserBadge.sorted(badges).prefix(limit))
    }

    var body: some View {
        if !visibleBadges.isEmpty {
            HStack(spacing: 5) {
                ForEach(visibleBadges) { badge in
                    Button {
                        selectedBadge = badge
                    } label: {
                        badgeIconButtonLabel(for: badge)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(badge.title), \(badge.rarity.localizedTitle)")
                    .accessibilityHint("Открыть описание значка")
                }
            }
            .fixedSize(horizontal: true, vertical: false)
            .userBadgeDetailPresentation(selectedBadge: $selectedBadge)
        }
    }

    private func badgeIconButtonLabel(for badge: UserBadge) -> some View {
        UserBadgeIconView(badge: badge, size: iconSize)
            .frame(width: iconSize + 4, height: iconSize + 4)
            .contentShape(Rectangle())
    }
}

struct UserBadgeGalleryView: View {
    let badges: [UserBadge]
    var showsEmptyState = true

    @State private var selectedBadge: UserBadge?

    private var sortedBadges: [UserBadge] {
        UserBadge.sorted(badges)
    }

    var body: some View {
        if !sortedBadges.isEmpty || showsEmptyState {
            VStack(alignment: .leading, spacing: 10) {
                Text("Значки")
                    .font(.caption)
                    .foregroundColor(.secondary)

                if sortedBadges.isEmpty {
                    Text("Пока нет значков")
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 4)
                } else {
                    if #available(iOS 16.0, macOS 13.0, *) {
                        RoleBadgeFlowLayout(horizontalSpacing: 10, verticalSpacing: 10) {
                            ForEach(sortedBadges) { badge in
                                galleryButton(for: badge)
                            }
                        }
                    } else {
                        VStack(alignment: .leading, spacing: 10) {
                            ForEach(sortedBadges) { badge in
                                galleryButton(for: badge)
                            }
                        }
                    }
                }
            }
            .userBadgeDetailPresentation(selectedBadge: $selectedBadge)
        }
    }

    private func galleryButton(for badge: UserBadge) -> some View {
        Button {
            selectedBadge = badge
        } label: {
            HStack(spacing: 9) {
                UserBadgeIconView(badge: badge, size: 40)
                VStack(alignment: .leading, spacing: 2) {
                    Text(badge.title)
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    Text(badge.rarity.localizedTitle)
                        .font(.caption2.weight(.medium))
                        .foregroundColor(badge.rarity.tint)
                        .lineLimit(1)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(badge.rarity.tint.opacity(0.10))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(badge.rarity.tint.opacity(0.26), lineWidth: 0.8)
            )
            .mympsuGlass(in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(badge.title), \(badge.rarity.localizedTitle). \(badge.description)")
    }
}

private struct UserBadgeDetailView: View {
    let badge: UserBadge
    var onClose: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: 14) {
            #if os(macOS)
            HStack {
                Spacer(minLength: 0)
                Button {
                    onClose?()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Закрыть")
            }
            #endif

            UserBadgeIconView(badge: badge, size: 64)
                .padding(.top, 10)

            VStack(spacing: 5) {
                Text(badge.title)
                    .font(.headline.weight(.semibold))
                    .multilineTextAlignment(.center)

                Text(badge.rarity.localizedTitle)
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(badge.rarity.tint)
            }

            if !badge.description.mympsuTrimmed.isEmpty {
                Text(badge.description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
#if os(macOS)
        .padding(18)
        .frame(width: 300)
#else
        .padding(22)
        .frame(maxWidth: 360)
#endif
        .presentationDetentsIfAvailable()
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(badge.title). \(badge.rarity.localizedTitle). \(badge.description)")
    }
}

private extension BadgeRarity {
    var tint: Color {
        switch self {
        case .legendary:
            return Color(red: 0.97, green: 0.64, blue: 0.22)
        case .epic:
            return Color(red: 0.70, green: 0.42, blue: 0.95)
        case .rare:
            return Color(red: 0.32, green: 0.61, blue: 0.96)
        case .common:
            return Color.secondary
        }
    }
}

private extension View {
    @ViewBuilder
    func userBadgeDetailPresentation(selectedBadge: Binding<UserBadge?>) -> some View {
#if os(macOS)
        self.popover(
            isPresented: Binding(
                get: { selectedBadge.wrappedValue != nil },
                set: { isPresented in
                    if !isPresented {
                        selectedBadge.wrappedValue = nil
                    }
                }
            ),
            arrowEdge: .bottom
        ) {
            if let badge = selectedBadge.wrappedValue {
                UserBadgeDetailView(badge: badge) {
                    selectedBadge.wrappedValue = nil
                }
            }
        }
#else
        self.sheet(item: selectedBadge) { badge in
            UserBadgeDetailView(badge: badge)
        }
#endif
    }

    @ViewBuilder
    func presentationDetentsIfAvailable() -> some View {
#if os(iOS)
        if #available(iOS 16.0, *) {
            self.presentationDetents([.medium])
        } else {
            self
        }
#else
        self
#endif
    }
}

@available(iOS 16.0, macOS 13.0, *)
private struct RoleBadgeFlowLayout: Layout {
    let horizontalSpacing: CGFloat
    let verticalSpacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = makeRows(proposal: proposal, subviews: subviews)
        let width = proposal.width ?? rows.map(\.width).max() ?? 0
        let height = rows.reduce(CGFloat.zero) { total, row in
            total + row.height
        } + verticalSpacing * CGFloat(max(0, rows.count - 1))

        return CGSize(width: width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let rows = makeRows(proposal: ProposedViewSize(width: bounds.width, height: proposal.height), subviews: subviews)
        var y = bounds.minY

        for row in rows {
            var x = bounds.minX
            for item in row.items {
                subviews[item.index].place(
                    at: CGPoint(x: x, y: y),
                    anchor: .topLeading,
                    proposal: ProposedViewSize(item.size)
                )
                x += item.size.width + horizontalSpacing
            }
            y += row.height + verticalSpacing
        }
    }

    private func makeRows(proposal: ProposedViewSize, subviews: Subviews) -> [RoleBadgeFlowRow] {
        let maxWidth = proposal.width ?? .infinity
        var rows: [RoleBadgeFlowRow] = []
        var currentItems: [RoleBadgeFlowItem] = []
        var currentWidth: CGFloat = 0
        var currentHeight: CGFloat = 0

        for index in subviews.indices {
            let size = subviews[index].sizeThatFits(.unspecified)
            let nextWidth = currentItems.isEmpty ? size.width : currentWidth + horizontalSpacing + size.width

            if nextWidth > maxWidth, !currentItems.isEmpty {
                rows.append(RoleBadgeFlowRow(items: currentItems, width: currentWidth, height: currentHeight))
                currentItems = [RoleBadgeFlowItem(index: index, size: size)]
                currentWidth = size.width
                currentHeight = size.height
            } else {
                currentItems.append(RoleBadgeFlowItem(index: index, size: size))
                currentWidth = nextWidth
                currentHeight = max(currentHeight, size.height)
            }
        }

        if !currentItems.isEmpty {
            rows.append(RoleBadgeFlowRow(items: currentItems, width: currentWidth, height: currentHeight))
        }

        return rows
    }
}

private struct RoleBadgeFlowRow {
    let items: [RoleBadgeFlowItem]
    let width: CGFloat
    let height: CGFloat
}

private struct RoleBadgeFlowItem {
    let index: Int
    let size: CGSize
}
