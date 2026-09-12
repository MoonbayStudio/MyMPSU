import SwiftUI

struct SidebarView: View {
    @Binding var selectedView: Int

    private let items: [(title: String, icon: String)] = [
        ("Расписание", "calendar"),
        ("Помощник МПГУ", "bubble.left.and.bubble.right.fill"),
        ("Сессия", "graduationcap.fill"),
        ("Аккаунт", "person.crop.circle.fill"),
        ("Меню", "line.3.horizontal")
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(items.indices, id: \.self) { index in
                Button {
                    selectedView = index
                } label: {
                    Label(items[index].title, systemImage: items[index].icon)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .foregroundColor(selectedView == index ? .white : .primary)
                        .padding(.horizontal, 12)
                        .frame(height: 38)
                        .background(selectedView == index ? Color.accentColor : Color.clear)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .buttonStyle(.plain)
            }
            Spacer()
        }
        .padding(.vertical, 16)
    }
}
