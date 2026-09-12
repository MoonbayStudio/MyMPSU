import SwiftUI
internal import Combine

@MainActor
final class PremiumViewModel: ObservableObject {
    @Published var selectedPeriod: SubscriptionPeriod = .yearly
    @Published var selectedPlanID: String?

    func bootstrapSelection(with manager: SubscriptionManager) {
        if selectedPlanID == nil {
            selectedPlanID = defaultPlanID(manager: manager)
        }
    }

    func selectPeriod(_ period: SubscriptionPeriod, manager: SubscriptionManager) {
        selectedPeriod = period
        let currentTier = selectedPlan(manager: manager)?.tier ?? .premium
        let sameTierPlan = manager.plan(tier: currentTier, period: period)
        selectedPlanID = sameTierPlan.isAvailable ? sameTierPlan.id : defaultPlanID(manager: manager)
    }

    func selectedPlan(manager: SubscriptionManager) -> SubscriptionPlan? {
        let visiblePlans = visiblePlans(manager: manager)
        if let selectedPlanID, let plan = visiblePlans.first(where: { $0.id == selectedPlanID }) {
            return plan
        }
        return visiblePlans.first(where: { $0.isAvailable }) ?? visiblePlans.first
    }

    func visiblePlans(manager: SubscriptionManager) -> [SubscriptionPlan] {
        let plans = manager.availablePlans(for: selectedPeriod)
        if manager.activeTier == .premium {
            return plans.filter { $0.tier == .premium }
        }
        return plans
    }

    func defaultPlanID(manager: SubscriptionManager) -> String? {
        let premiumYearly = manager.plan(tier: .premium, period: .yearly)
        if premiumYearly.isAvailable { return premiumYearly.id }

        let premiumMonthly = manager.plan(tier: .premium, period: .monthly)
        if premiumMonthly.isAvailable { return premiumMonthly.id }

        return SubscriptionPeriod.allCases
            .flatMap { manager.availablePlans(for: $0) }
            .first(where: { $0.isAvailable })?
            .id
    }

    func purchaseButtonTitle(for plan: SubscriptionPlan?, manager: SubscriptionManager) -> String {
        if manager.activeTier == .premium {
            return "Premium уже активен"
        }

        guard let plan else { return "Подписка недоступна" }

        switch plan.tier {
        case .plus:
            return "Оформить Plus\(plan.period.purchaseSuffix)"
        case .premium:
            return "Оформить Premium\(plan.period.purchaseSuffix)"
        case .none:
            return "Подписка недоступна"
        }
    }
}

struct PremiumView: View {
    @Environment(\.presentationMode) private var presentationMode
    @AppStorage("selectedThemeID") private var selectedThemeID = AppThemeCatalog.default
    @StateObject private var subscriptionManager = SubscriptionManager.shared
    @StateObject private var viewModel = PremiumViewModel()

    var showsHeader = true
    var onBack: (() -> Void)? = nil

    private var activeTheme: AppTheme { AppThemeCatalog.theme(for: selectedThemeID) }

    var body: some View {
        ZStack(alignment: .bottom) {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if showsHeader {
#if os(iOS)
                        header
#endif
                    }

                    heroSection
                    activeSubscriptionBanner
                    periodPicker
                    stateMessage
                    planCards
                    comparisonSection
                    legalSection
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 118)
            }

            bottomPurchaseBar
        }
        .background(ThemedBackground(theme: activeTheme).ignoresSafeArea())
#if os(iOS)
        .navigationBarBackButtonHidden(true)
        .navigationBarHidden(true)
#endif
        .onAppear {
            Task {
                await subscriptionManager.bootstrap()
                viewModel.bootstrapSelection(with: subscriptionManager)
            }
        }
        .onChange(of: subscriptionManager.productsByID) { _ in
            viewModel.bootstrapSelection(with: subscriptionManager)
        }
        .onChange(of: subscriptionManager.activeTier) { _ in
            viewModel.bootstrapSelection(with: subscriptionManager)
        }
    }

    @ViewBuilder
    private var header: some View {
        MyMPSUTitleBackHeader(
            shape: activeTheme.headerShape,
            title: "Подписка",
            onBack: { dismissView() }
        )
    }

    private var heroSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Выберите план")
                .font(.largeTitle.weight(.bold))
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            Text("Больше возможностей для Помощника МПГУ, тем и расписания")
                .font(.body)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .mympsuDefaultSurface(cornerRadius: 22, padding: 16)
    }

    @ViewBuilder
    private var activeSubscriptionBanner: some View {
        switch subscriptionManager.activeTier {
        case .premium:
            activeBanner(title: "У вас активен MyMPSU Premium", icon: "crown.fill")
        case .plus:
            activeBanner(title: "У вас активен MyMPSU Plus", icon: "sparkles")
        case .none:
            EmptyView()
        }
    }

    private func activeBanner(title: String, icon: String) -> some View {
        Label(title, systemImage: icon)
            .font(.subheadline.weight(.semibold))
            .foregroundColor(.primary)
            .mympsuDefaultSurface(cornerRadius: 18, padding: 12)
    }

    private var periodPicker: some View {
        Picker("Период оплаты", selection: Binding(
            get: { viewModel.selectedPeriod },
            set: { viewModel.selectPeriod($0, manager: subscriptionManager) }
        )) {
            ForEach(SubscriptionPeriod.allCases) { period in
                Text(period.title).tag(period)
            }
        }
        .pickerStyle(.segmented)
        .mympsuControlTintStyle()
    }

    @ViewBuilder
    private var stateMessage: some View {
        if subscriptionManager.isLoading && subscriptionManager.productsByID.isEmpty {
            Label("Загружаем подписки...", systemImage: "clock")
                .font(.caption.weight(.semibold))
                .foregroundColor(.secondary)
                .mympsuDefaultSurface(cornerRadius: 16, padding: 12)
        } else if subscriptionManager.state == .productLoadFailed {
            VStack(alignment: .leading, spacing: 8) {
                Label("Подписки временно недоступны", systemImage: "exclamationmark.triangle.fill")
                    .font(.subheadline.weight(.semibold))
                Text(subscriptionManager.userMessage ?? "Попробуйте обновить экран позже.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Button("Повторить") {
                    Task { await subscriptionManager.loadProducts() }
                }
                .buttonStyle(.bordered)
            }
            .mympsuDefaultSurface(cornerRadius: 18, padding: 12)
        } else if let message = subscriptionManager.userMessage {
            Text(message)
                .font(.caption.weight(.semibold))
                .foregroundColor(messageColor)
                .mympsuDefaultSurface(cornerRadius: 16, padding: 12)
        }
    }

    private var planCards: some View {
        VStack(spacing: 12) {
            ForEach(viewModel.visiblePlans(manager: subscriptionManager)) { plan in
                planCard(plan)
            }
        }
        .onAppear { viewModel.bootstrapSelection(with: subscriptionManager) }
    }

    private func planCard(_ plan: SubscriptionPlan) -> some View {
        let isSelected = viewModel.selectedPlanID == plan.id
        let isCurrent = subscriptionManager.activeTier == plan.tier
        let isPremium = plan.tier == .premium
        let yearlyBetter = plan.period == .yearly && subscriptionManager.isYearlyBetterValue(for: plan.tier)

        return Button {
            guard plan.isAvailable else { return }
            guard subscriptionManager.activeTier != .premium else { return }
            viewModel.selectedPlanID = plan.id
        } label: {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top, spacing: 10) {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 8) {
                            Text(plan.tier.shortName)
                                .font(.title2.weight(.bold))
                            if isPremium {
                                badge("Лучший выбор", prominent: true)
                            }
                            if yearlyBetter {
                                badge("Выгоднее", prominent: false)
                            }
                        }

                        Text(plan.subtitle)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 2) {
                        Text(plan.displayPrice)
                            .font(.title3.weight(.bold))
                        Text(plan.period.priceSuffix)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    ForEach(plan.benefits, id: \.self) { benefit in
                        Label(benefit, systemImage: "checkmark.circle.fill")
                            .font(.subheadline)
                            .foregroundColor(.primary)
                    }
                }

                HStack {
                    if isCurrent {
                        Text("Текущий план")
                            .font(.caption.weight(.semibold))
                            .foregroundColor(.secondary)
                    } else if !plan.isAvailable {
                        Text("Недоступно")
                            .font(.caption.weight(.semibold))
                            .foregroundColor(.secondary)
                    } else if subscriptionManager.activeTier == .plus && plan.tier == .premium {
                        Text("Можно перейти на Premium")
                            .font(.caption.weight(.semibold))
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.title3.weight(.semibold))
                        .foregroundColor(isSelected ? .accentColor : .secondary)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(planCardBackground(isPremium: isPremium))
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(planCardStroke(isSelected: isSelected, isPremium: isPremium), lineWidth: isSelected ? 2 : 0.9)
            )
            .shadow(color: isPremium ? Color.black.opacity(0.16) : Color.black.opacity(0.08), radius: isPremium ? 16 : 8, x: 0, y: 8)
        }
        .buttonStyle(.plain)
        .disabled(!plan.isAvailable || subscriptionManager.activeTier == .premium)
        .opacity(plan.isAvailable ? 1 : 0.62)
    }

    private func badge(_ title: String, prominent: Bool) -> some View {
        Text(title)
            .font(.caption2.weight(.bold))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .foregroundColor(prominent ? .white : .primary)
            .background(prominent ? Color.accentColor : Color.mympsuHeaderCapsuleFill)
            .clipShape(Capsule())
    }

    @ViewBuilder
    private func planCardBackground(isPremium: Bool) -> some View {
        if activeTheme.usesCloudSurface {
            activeTheme.cloudSurfaceFill
        } else if isPremium {
#if os(iOS)
            Color(UIColor.secondarySystemBackground)
#elseif os(macOS)
            Color(NSColor.windowBackgroundColor)
#else
            Color.mympsuHeaderCapsuleFill
#endif
        } else {
            MyMPSUAdaptiveMaterialFill()
        }
    }

    private func planCardStroke(isSelected: Bool, isPremium: Bool) -> Color {
        if isSelected { return .accentColor }
        if activeTheme.usesCloudSurface { return activeTheme.cloudSurfaceStroke }
        return isPremium ? Color.accentColor.opacity(0.35) : Color.white.opacity(0.22)
    }

    private var comparisonSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Сравнение планов")
                .font(.headline)

            comparisonHeader
            comparisonRow(feature: "Помощник МПГУ", free: "базовый лимит", plus: "больше запросов", premium: "максимум запросов")
            comparisonRow(feature: "Темы", free: "стандартные", plus: "кастомные", premium: "все темы")
            comparisonRow(feature: "Новые функции", free: "нет", plus: "нет", premium: "ранний доступ")
        }
        .mympsuDefaultSurface(cornerRadius: 22, padding: 14)
    }

    private var comparisonHeader: some View {
        HStack(alignment: .top, spacing: 8) {
            comparisonCell("Функция", weight: .semibold)
            comparisonCell("Free", weight: .semibold)
            comparisonCell("Plus", weight: .semibold)
            comparisonCell("Premium", weight: .semibold)
        }
        .font(.caption)
        .foregroundColor(.secondary)
    }

    private func comparisonRow(feature: String, free: String, plus: String, premium: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            comparisonCell(feature, weight: .semibold)
            comparisonCell(free)
            comparisonCell(plus)
            comparisonCell(premium)
        }
        .font(.caption)
    }

    private func comparisonCell(_ text: String, weight: Font.Weight = .regular) -> some View {
        Text(text)
            .fontWeight(weight)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var legalSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Подписка автоматически продлевается, если не отменена минимум за 24 часа до окончания текущего периода.")
                .font(.caption)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 12) {
                legalLink(title: "Политика конфиденциальности", url: nil)
                legalLink(title: "Пользовательское соглашение", url: nil)
            }

            Button {
                Task { await subscriptionManager.restorePurchases() }
            } label: {
                Label("Восстановить покупки", systemImage: "arrow.clockwise")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .mympsuControlTintStyle()
            .disabled(subscriptionManager.isLoading || subscriptionManager.isPurchasing)
        }
        .mympsuDefaultSurface(cornerRadius: 20, padding: 14)
    }

    @ViewBuilder
    private func legalLink(title: String, url: URL?) -> some View {
        if let url {
            Link(title, destination: url)
                .font(.caption.weight(.semibold))
        } else {
            // TODO: Add production legal URLs before App Store submission.
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundColor(.secondary)
        }
    }

    private var bottomPurchaseBar: some View {
        let selectedPlan = viewModel.selectedPlan(manager: subscriptionManager)
        let isPremiumActive = subscriptionManager.activeTier == .premium
        let canPurchase = selectedPlan?.isAvailable == true && !isPremiumActive && !subscriptionManager.isPurchasing

        return VStack(spacing: 8) {
            Button {
                guard let selectedPlan else { return }
                Task { await subscriptionManager.purchase(selectedPlan) }
            } label: {
                HStack {
                    if subscriptionManager.isPurchasing {
                        ProgressView()
                    }
                    Text(viewModel.purchaseButtonTitle(for: selectedPlan, manager: subscriptionManager))
                        .font(.headline.weight(.bold))
                }
                .frame(maxWidth: .infinity)
                .frame(height: 52)
            }
            .premiumPurchaseButtonStyle()
            .mympsuControlTintStyle()
            .disabled(!canPurchase)

            if let selectedPlan, selectedPlan.isAvailable, !isPremiumActive {
                Text("Выбран план: \(selectedPlan.tier.displayName), \(selectedPlan.period.priceSuffix)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 12)
        .background(bottomBarBackground)
    }

    @ViewBuilder
    private var bottomBarBackground: some View {
#if os(iOS)
        if #available(iOS 15.0, *) {
            Color.clear.background(.ultraThinMaterial)
        } else {
            Color(UIColor.systemBackground)
        }
#elseif os(macOS)
        if #available(macOS 12.0, *) {
            Color.clear.background(.ultraThinMaterial)
        } else {
            Color(NSColor.windowBackgroundColor)
        }
#else
        Color.clear
#endif
    }

    private var messageColor: Color {
        switch subscriptionManager.state {
        case .purchaseFailed, .productLoadFailed:
            return .red
        case .purchaseCancelled, .purchasePending:
            return .secondary
        default:
            return .secondary
        }
    }

    private func dismissView() {
        if let onBack {
            onBack()
        } else {
            presentationMode.wrappedValue.dismiss()
        }
    }
}

private struct PremiumPurchaseButtonStyleModifier: ViewModifier {
    @ViewBuilder
    func body(content: Content) -> some View {
#if os(macOS)
        if #available(macOS 12.0, *) {
            content.buttonStyle(.borderedProminent)
        } else {
            content.buttonStyle(.bordered)
        }
#else
        content.buttonStyle(.borderedProminent)
#endif
    }
}

private extension View {
    func premiumPurchaseButtonStyle() -> some View {
        modifier(PremiumPurchaseButtonStyleModifier())
    }
}
