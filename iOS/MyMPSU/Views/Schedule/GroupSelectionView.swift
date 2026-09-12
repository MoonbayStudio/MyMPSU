import SwiftUI

struct GroupSelectionView: View {
    @Binding var selectedGroup: MyGroup?
    @Binding var menuTitle: String
    @Binding var selectedMenuSubView: ContentView.MenuSubView?
    @ObservedObject var viewModel: ScheduleViewModel
    var onBack: (() -> Void)? = nil

    @AppStorage("selectedThemeID") private var selectedThemeID = AppThemeCatalog.default
    @AppStorage("selectedGroupId") private var defaultGroupId = ""
    @State private var institutes: [Institute] = []
    @State private var searchText = ""
    @State private var isLoading = false
    @State private var selectionMessage: String?
    @State private var submittingGroupId: String?
    @State private var pendingInitialDefaultGroup: MyGroup?
    @State private var showsInitialDefaultGroupWarning = false

    private var activeTheme: AppTheme {
        AppThemeCatalog.theme(for: selectedThemeID)
    }

    private var filteredGroups: [MyGroup] {
        let allGroups = institutes.flatMap(\.groups)
        let query = searchText.mympsuTrimmed.lowercased()
        guard !query.isEmpty else { return allGroups }
        return allGroups.filter {
            $0.name.lowercased().contains(query) || $0.id.lowercased().contains(query)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
#if os(iOS)
            MyMPSUTitleBackHeader(shape: activeTheme.headerShape, title: "Выбор группы") {
                dismiss()
            }
#endif

            TextField("Найти группу", text: $searchText)
                .textFieldStyle(.plain)
                .padding(12)
                .mympsuDefaultSurface(cornerRadius: 14, padding: 0)

            if let selectionMessage {
                Text(selectionMessage)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 4)
            }

            Group {
                if isLoading && institutes.isEmpty {
                    VStack(spacing: 12) {
                        ProgressView()
                        Text("Загружаем группы")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                } else if filteredGroups.isEmpty {
                    VStack(spacing: 8) {
                        Text("Группы не найдены")
                            .font(.headline)
                        Text("Попробуй изменить поисковый запрос.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                } else {
                    List(filteredGroups) { group in
                        Button {
                            select(group)
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 0) {
                                    Text(group.name)
                                        .font(.body.weight(.semibold))
                                }
                                Spacer()
                                if submittingGroupId == group.id {
                                    ProgressView()
                                        .scaleEffect(0.75)
                                } else if selectedGroup?.id == group.id || viewModel.savedGroupId == group.id {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.accentColor)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                        .disabled(submittingGroupId != nil)
                    }
                    .listStyle(.plain)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(.horizontal, 16)
        .padding(.top, 16)
        .background(ThemedBackground(theme: activeTheme).ignoresSafeArea())
        .onAppear {
            Task {
                await loadGroups()
            }
        }
        .alert(isPresented: $showsInitialDefaultGroupWarning) {
            Alert(
                title: Text("Группа по умолчанию"),
                message: Text("Эта группа будет привязана к аккаунту. По ней будут показываться домашка и участники. Позже сменить её можно будет только через заявку модератору."),
                primaryButton: .default(Text("Понял")) {
                    confirmInitialDefaultGroupSelection()
                },
                secondaryButton: .cancel(Text("Отмена")) {
                    pendingInitialDefaultGroup = nil
                }
            )
        }
    }

    private func loadGroups() async {
        guard institutes.isEmpty else { return }
        isLoading = true
        let cached = APIService.shared.fetchCachedInstitutesWithGroups()
        if !cached.isEmpty {
            institutes = cached
        }
        let loaded = await APIService.shared.fetchInstitutesWithGroups()
        if !loaded.isEmpty {
            institutes = loaded
        }
        isLoading = false
    }

    private func select(_ group: MyGroup) {
        guard submittingGroupId == nil else { return }
        selectionMessage = nil

        if !defaultGroupId.mympsuTrimmed.isEmpty {
            applyScheduleGroup(group)
            dismiss()
            return
        }

        pendingInitialDefaultGroup = group
        showsInitialDefaultGroupWarning = true
    }

    private func confirmInitialDefaultGroupSelection() {
        guard let group = pendingInitialDefaultGroup else { return }
        pendingInitialDefaultGroup = nil
        submitInitialDefaultGroup(group)
    }

    private func submitInitialDefaultGroup(_ group: MyGroup) {
        submittingGroupId = group.id
        Task {
            let result = await UserSettingsSyncService.updateRemoteSelectedGroupIfAuthenticated(group)
            await MainActor.run {
                submittingGroupId = nil
                switch result {
                case .applied:
                    applyScheduleGroup(group)
                    dismiss()
                case .changeRequestCreated:
                    selectionMessage = "Заявка на смену группы отправлена модератору."
                case .authenticationRequired:
                    selectionMessage = "Чтобы сменить группу, войдите в аккаунт."
                case .failed:
                    selectionMessage = "Не удалось обновить группу. Попробуйте ещё раз."
                }
            }
        }
    }

    private func applyScheduleGroup(_ group: MyGroup) {
        selectedGroup = group
        viewModel.savedGroupId = group.id
        UserDefaults.standard.set(group.name, forKey: "scheduleGroupName")
        UserDefaults(suiteName: "group.mympsu.shared")?.set(group.name, forKey: "scheduleGroupName")
    }

    private func dismiss() {
        if let onBack {
            onBack()
        } else {
            withAnimation(.easeInOut(duration: 0.18)) {
                selectedMenuSubView = nil
                menuTitle = "Меню"
            }
        }
    }
}
