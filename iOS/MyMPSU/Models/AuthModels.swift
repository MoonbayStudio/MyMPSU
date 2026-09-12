import Foundation

struct AppleSignInResponse: Decodable {
    let token: String
    let user: AppleUser
}

struct GoogleSignInRequest: Encodable {
    let idToken: String
    let accessToken: String
    let googleUserID: String?
    let fullName: String?
    let email: String?
    let deviceId: String
    let deviceName: String?
    let platform: String
    let appVersion: String?
}

struct UserRole: Codable, Identifiable, Hashable {
    static let roleOrder: [String: Int] = [
        "admin": 0,
        "moderator": 1,
        "group_leader": 2,
        "tester": 3,
        "premium": 4,
        "plus": 5,
        "free": 6,
        "student": 7,
        "group": 8
    ]
    static let manageableTypes = ["admin", "tester", "premium", "plus", "free", "group_leader", "moderator"]

    let type: String
    let title: String

    var id: String {
        type
    }

    init(type: String, title: String? = nil) {
        self.type = type
        self.title = title ?? Self.defaultTitle(for: type)
    }

    init(from decoder: Decoder) throws {
        if let container = try? decoder.container(keyedBy: CodingKeys.self) {
            type = try container.decode(String.self, forKey: .type)
            title = try container.decodeIfPresent(String.self, forKey: .title) ?? Self.defaultTitle(for: type)
        } else {
            let container = try decoder.singleValueContainer()
            let rawType = try container.decode(String.self)
            type = rawType
            title = Self.defaultTitle(for: rawType)
        }
    }

    private enum CodingKeys: String, CodingKey {
        case type
        case title
    }

    static func defaultTitle(for type: String) -> String {
        switch type {
        case "admin":
            return "Админ"
        case "moderator":
            return "Модератор"
        case "group_leader":
            return "Староста"
        case "student":
            return "Студент"
        case "group":
            return "Группа"
        case "tester":
            return "Тестировщик"
        case "premium":
            return "Премиум"
        case "plus":
            return "Плюс"
        case "free":
            return "Бесплатный"
        default:
            return type
        }
    }
}

enum BadgeRarity: String, Codable, CaseIterable {
    case common
    case rare
    case epic
    case legendary

    var sortPriority: Int {
        switch self {
        case .legendary:
            return 0
        case .epic:
            return 1
        case .rare:
            return 2
        case .common:
            return 3
        }
    }

    var localizedTitle: String {
        switch self {
        case .legendary:
            return "Легендарный"
        case .epic:
            return "Эпический"
        case .rare:
            return "Редкий"
        case .common:
            return "Обычный"
        }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = (try? container.decode(String.self)) ?? ""
        self = BadgeRarity(rawValue: rawValue) ?? .common
    }
}

struct UserBadge: Codable, Identifiable, Hashable {
    let code: String
    let title: String
    let description: String
    let iconName: String
    let rarity: BadgeRarity

    var id: String { code }

    var hasKnownAsset: Bool {
        Self.knownAssetNames.contains(iconName)
    }

    static func sorted(_ badges: [UserBadge]) -> [UserBadge] {
        badges
            .filter(\.hasKnownAsset)
            .sorted { lhs, rhs in
                areInDisplayOrder(lhs, rhs)
            }
    }

    static func sortedForAdministration(_ badges: [UserBadge]) -> [UserBadge] {
        badges
            .sorted { lhs, rhs in
                areInDisplayOrder(lhs, rhs)
            }
    }

    private static func areInDisplayOrder(_ lhs: UserBadge, _ rhs: UserBadge) -> Bool {
        if lhs.rarity.sortPriority != rhs.rarity.sortPriority {
            return lhs.rarity.sortPriority < rhs.rarity.sortPriority
        }
        let titleComparison = lhs.title.localizedStandardCompare(rhs.title)
        if titleComparison != .orderedSame {
            return titleComparison == .orderedAscending
        }
        return lhs.code.localizedStandardCompare(rhs.code) == .orderedAscending
    }

    private static let knownAssetNames: Set<String> = [
        "badge_first_tester",
        "badge_active_tester"
    ]

    private enum CodingKeys: String, CodingKey {
        case code
        case title
        case description
        case iconName
        case snakeIconName = "icon_name"
        case rarity
    }

    init(
        code: String,
        title: String,
        description: String,
        iconName: String,
        rarity: BadgeRarity
    ) {
        self.code = code
        self.title = title
        self.description = description
        self.iconName = iconName
        self.rarity = rarity
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        code = try container.decodeIfPresent(String.self, forKey: .code) ?? ""
        title = try container.decodeIfPresent(String.self, forKey: .title) ?? code
        description = try container.decodeIfPresent(String.self, forKey: .description) ?? ""
        iconName = try container.decodeIfPresent(String.self, forKey: .iconName)
            ?? container.decodeIfPresent(String.self, forKey: .snakeIconName)
            ?? ""
        rarity = try container.decodeIfPresent(BadgeRarity.self, forKey: .rarity) ?? .common
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(code, forKey: .code)
        try container.encode(title, forKey: .title)
        try container.encode(description, forKey: .description)
        try container.encode(iconName, forKey: .iconName)
        try container.encode(rarity, forKey: .rarity)
    }
}

struct AppleUser: Codable, Equatable {
    let id: String
    let name: String?
    let displayName: String
    let email: String?
    let primaryEmail: String?
    let emailVerified: Bool
    let pendingEmail: String?
    let appleEmail: String?
    let linkedProviders: [String]
    let contactEmail: String?
    let contactEmailVerified: Bool
    let pendingContactEmail: String?
    let needsContactEmail: Bool
    let isAppleRelayEmail: Bool
    let badges: [UserBadge]
    let roles: [UserRole]
    let tier: String?
    let remainingToday: Int?
    let permissions: [String]
    let hasPassword: Bool

    init(
        id: String,
        name: String? = nil,
        displayName: String,
        email: String?,
        primaryEmail: String? = nil,
        emailVerified: Bool = false,
        pendingEmail: String? = nil,
        appleEmail: String? = nil,
        linkedProviders: [String] = [],
        contactEmail: String? = nil,
        contactEmailVerified: Bool = false,
        pendingContactEmail: String? = nil,
        needsContactEmail: Bool = false,
        isAppleRelayEmail: Bool = false,
        badges: [UserBadge] = [],
        roles: [UserRole] = [],
        tier: String? = nil,
        remainingToday: Int? = nil,
        permissions: [String] = [],
        hasPassword: Bool = false
    ) {
        self.id = id
        self.name = name
        self.displayName = displayName
        self.email = email
        self.primaryEmail = primaryEmail
        self.emailVerified = emailVerified
        self.pendingEmail = pendingEmail
        self.appleEmail = appleEmail
        self.linkedProviders = linkedProviders
        self.contactEmail = contactEmail
        self.contactEmailVerified = contactEmailVerified
        self.pendingContactEmail = pendingContactEmail
        self.needsContactEmail = needsContactEmail
        self.isAppleRelayEmail = isAppleRelayEmail
        self.badges = badges
        self.roles = roles
        self.tier = tier
        self.remainingToday = remainingToday
        self.permissions = permissions
        self.hasPassword = hasPassword
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case name
        case displayName
        case snakeDisplayName = "display_name"
        case email
        case primaryEmail
        case snakePrimaryEmail = "primary_email"
        case emailVerified
        case snakeEmailVerified = "email_verified"
        case pendingEmail
        case snakePendingEmail = "pending_email"
        case appleEmail
        case snakeAppleEmail = "apple_email"
        case linkedProviders
        case snakeLinkedProviders = "linked_providers"
        case contactEmail
        case snakeContactEmail = "contact_email"
        case contactEmailVerified
        case snakeContactEmailVerified = "contact_email_verified"
        case pendingContactEmail
        case snakePendingContactEmail = "pending_contact_email"
        case needsContactEmail
        case snakeNeedsContactEmail = "needs_contact_email"
        case isAppleRelayEmail
        case snakeIsAppleRelayEmail = "is_apple_relay_email"
        case badges
        case roles
        case tier
        case remainingToday
        case snakeRemainingToday = "remaining_today"
        case permissions
        case hasPassword
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decodeIfPresent(String.self, forKey: .name)
        displayName = try container.decodeIfPresent(String.self, forKey: .displayName)
            ?? container.decodeIfPresent(String.self, forKey: .snakeDisplayName)
            ?? name
            ?? ""
        email = try container.decodeIfPresent(String.self, forKey: .email)
        primaryEmail = try container.decodeIfPresent(String.self, forKey: .primaryEmail)
            ?? container.decodeIfPresent(String.self, forKey: .snakePrimaryEmail)
        emailVerified = try container.decodeIfPresent(Bool.self, forKey: .emailVerified)
            ?? container.decodeIfPresent(Bool.self, forKey: .snakeEmailVerified)
            ?? false
        pendingEmail = try container.decodeIfPresent(String.self, forKey: .pendingEmail)
            ?? container.decodeIfPresent(String.self, forKey: .snakePendingEmail)
        appleEmail = try container.decodeIfPresent(String.self, forKey: .appleEmail)
            ?? container.decodeIfPresent(String.self, forKey: .snakeAppleEmail)
        linkedProviders = try container.decodeIfPresent([String].self, forKey: .linkedProviders)
            ?? container.decodeIfPresent([String].self, forKey: .snakeLinkedProviders)
            ?? []
        contactEmail = try container.decodeIfPresent(String.self, forKey: .contactEmail)
            ?? container.decodeIfPresent(String.self, forKey: .snakeContactEmail)
        contactEmailVerified = try container.decodeIfPresent(Bool.self, forKey: .contactEmailVerified)
            ?? container.decodeIfPresent(Bool.self, forKey: .snakeContactEmailVerified)
            ?? false
        pendingContactEmail = try container.decodeIfPresent(String.self, forKey: .pendingContactEmail)
            ?? container.decodeIfPresent(String.self, forKey: .snakePendingContactEmail)
        needsContactEmail = try container.decodeIfPresent(Bool.self, forKey: .needsContactEmail)
            ?? container.decodeIfPresent(Bool.self, forKey: .snakeNeedsContactEmail)
            ?? false
        isAppleRelayEmail = try container.decodeIfPresent(Bool.self, forKey: .isAppleRelayEmail)
            ?? container.decodeIfPresent(Bool.self, forKey: .snakeIsAppleRelayEmail)
            ?? false
        badges = try container.decodeIfPresent([UserBadge].self, forKey: .badges) ?? []
        roles = try container.decodeIfPresent([UserRole].self, forKey: .roles) ?? []
        tier = try container.decodeIfPresent(String.self, forKey: .tier)
        remainingToday = try container.decodeIfPresent(Int.self, forKey: .remainingToday)
            ?? container.decodeIfPresent(Int.self, forKey: .snakeRemainingToday)
        permissions = try container.decodeIfPresent([String].self, forKey: .permissions) ?? []
        hasPassword = try container.decodeIfPresent(Bool.self, forKey: .hasPassword) ?? false
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encodeIfPresent(name, forKey: .name)
        try container.encode(displayName, forKey: .displayName)
        try container.encodeIfPresent(email, forKey: .email)
        try container.encodeIfPresent(primaryEmail, forKey: .primaryEmail)
        try container.encode(emailVerified, forKey: .emailVerified)
        try container.encodeIfPresent(pendingEmail, forKey: .pendingEmail)
        try container.encodeIfPresent(appleEmail, forKey: .appleEmail)
        try container.encode(linkedProviders, forKey: .linkedProviders)
        try container.encodeIfPresent(contactEmail, forKey: .contactEmail)
        try container.encode(contactEmailVerified, forKey: .contactEmailVerified)
        try container.encodeIfPresent(pendingContactEmail, forKey: .pendingContactEmail)
        try container.encode(needsContactEmail, forKey: .needsContactEmail)
        try container.encode(isAppleRelayEmail, forKey: .isAppleRelayEmail)
        try container.encode(badges, forKey: .badges)
        try container.encode(roles, forKey: .roles)
        try container.encodeIfPresent(tier, forKey: .tier)
        try container.encodeIfPresent(remainingToday, forKey: .remainingToday)
        try container.encode(permissions, forKey: .permissions)
        try container.encode(hasPassword, forKey: .hasPassword)
    }
}

extension AppleUser {
    func applyingAdminSnapshot(_ adminUser: AdminUserDTO) -> AppleUser {
        AppleUser(
            id: id,
            name: preferredIdentityValue(name, fallback: adminUser.name),
            displayName: preferredIdentityValue(displayName, fallback: adminUser.displayName) ?? "",
            email: preferredIdentityValue(email, fallback: adminUser.email),
            primaryEmail: preferredIdentityValue(primaryEmail, fallback: adminUser.email),
            emailVerified: emailVerified,
            pendingEmail: pendingEmail,
            appleEmail: appleEmail,
            linkedProviders: linkedProviders,
            contactEmail: contactEmail,
            contactEmailVerified: contactEmailVerified,
            pendingContactEmail: pendingContactEmail,
            needsContactEmail: needsContactEmail,
            isAppleRelayEmail: isAppleRelayEmail,
            badges: adminUser.badges,
            roles: adminUser.roles,
            tier: adminUser.tier,
            remainingToday: adminUser.remainingToday,
            permissions: permissions,
            hasPassword: hasPassword
        )
    }

    func preservingMissingIdentityFields(from savedUser: AppleUser?) -> AppleUser {
        guard let savedUser, savedUser.id == id else { return self }

        return AppleUser(
            id: id,
            name: preferredIdentityValue(name, fallback: savedUser.name),
            displayName: preferredIdentityValue(displayName, fallback: savedUser.displayName) ?? "",
            email: preferredIdentityValue(email, fallback: savedUser.email),
            primaryEmail: preferredIdentityValue(primaryEmail, fallback: savedUser.primaryEmail),
            emailVerified: emailVerified,
            pendingEmail: pendingEmail,
            appleEmail: preferredIdentityValue(appleEmail, fallback: savedUser.appleEmail),
            linkedProviders: linkedProviders,
            contactEmail: preferredIdentityValue(contactEmail, fallback: savedUser.contactEmail),
            contactEmailVerified: contactEmailVerified,
            pendingContactEmail: pendingContactEmail,
            needsContactEmail: needsContactEmail,
            isAppleRelayEmail: isAppleRelayEmail,
            badges: badges,
            roles: roles,
            tier: tier,
            remainingToday: remainingToday,
            permissions: permissions,
            hasPassword: hasPassword
        )
    }

    private func preferredIdentityValue(_ value: String?, fallback: String?) -> String? {
        guard let value else { return fallback }
        return value.mympsuTrimmed.isEmpty ? fallback : value
    }

    var accountEmail: String? {
        let value = primaryEmail?.mympsuTrimmed
        if let value, !value.isEmpty {
            return value
        }

        let legacyEmail = email?.mympsuTrimmed
        return legacyEmail?.isEmpty == false ? legacyEmail : nil
    }

    func matchesAdminUser(_ adminUser: AdminUserDTO) -> Bool {
        matchesAdminUser(id: adminUser.id) || normalizedAccountEmail == adminUser.normalizedEmail
    }

    func matchesAdminUser(id adminUserId: String?) -> Bool {
        guard let adminUserId, !adminUserId.isEmpty else { return false }
        return id == adminUserId
    }

    private var normalizedAccountEmail: String? {
        accountEmail?.mympsuTrimmed.lowercased()
    }

    var pendingAccountEmail: String? {
        let value = pendingEmail?.mympsuTrimmed
        return value?.isEmpty == false ? value : nil
    }

    var passwordContactEmail: String? {
        let value = contactEmail?.mympsuTrimmed
        return value?.isEmpty == false ? value : nil
    }

    var pendingPasswordContactEmail: String? {
        let value = pendingContactEmail?.mympsuTrimmed
        return value?.isEmpty == false ? value : nil
    }

    var needsPasswordContactEmail: Bool {
        needsContactEmail || passwordContactEmail == nil
    }

    var passwordContactEmailIsVerified: Bool {
        emailVerified || contactEmailVerified
    }

    var canCreatePassword: Bool {
        !needsPasswordContactEmail && passwordContactEmailIsVerified
    }

    var hasAppleProvider: Bool {
        hasLinkedProvider("apple")
    }

    var hasGoogleProvider: Bool {
        hasLinkedProvider("google")
    }

    private func hasLinkedProvider(_ provider: String) -> Bool {
        linkedProviders.contains { $0.caseInsensitiveCompare(provider) == .orderedSame }
    }

    var appleEmailIsRelay: Bool {
        isAppleRelayEmail
        || appleEmail?.localizedCaseInsensitiveContains("privaterelay.appleid.com") == true
        || accountEmail?.localizedCaseInsensitiveContains("privaterelay.appleid.com") == true
    }

    var accountEmailIsVerified: Bool {
        emailVerified
    }

    var displayNameForProfile: String {
        if let storedName = name?.mympsuTrimmed, !storedName.isEmpty {
            return storedName
        }

        let legacyDisplayName = displayName.mympsuTrimmed
        if !legacyDisplayName.isEmpty && legacyDisplayName != "Student" {
            return legacyDisplayName
        }

        if let emailUsername {
            return emailUsername
        }

        return "Пользователь"
    }

    var editableProfileName: String {
        if let storedName = name?.mympsuTrimmed, !storedName.isEmpty {
            return storedName
        }

        return ""
    }

    private var emailUsername: String? {
        guard let email = accountEmail, !email.isEmpty else { return nil }
        let username = email.split(separator: "@", maxSplits: 1).first.map(String.init)?.mympsuTrimmed ?? ""
        return username.isEmpty ? nil : username
    }

    var isAdmin: Bool {
        roleTypes.contains("admin")
    }

    var isModerator: Bool {
        roleTypes.contains("moderator")
    }

    var canViewAdminPanel: Bool {
        isAdmin
        || permissions.contains("view_admin_panel")
        || permissions.contains("permission/view_admin_panel")
    }

    var isTester: Bool {
        roleTypes.contains("tester")
    }

    var isGroupLeader: Bool {
        roleTypes.contains("group_leader")
    }

    var isStudent: Bool {
        roleTypes.contains("student")
    }

    var roleTypes: Set<String> {
        Set(roles.map(\.type))
    }

    func isGroupLeader(for groupId: Int) -> Bool {
        isGroupLeader
    }

    var primaryRoleTitle: String? {
        sortedRoles.first?.title
    }

    var sortedRoles: [UserRole] {
        roles.sorted { lhs, rhs in
            let lhsPriority = rolePriority(lhs.type)
            let rhsPriority = rolePriority(rhs.type)
            if lhsPriority != rhsPriority {
                return lhsPriority < rhsPriority
            }
            return lhs.title.localizedStandardCompare(rhs.title) == .orderedAscending
        }
    }

    private func rolePriority(_ type: String) -> Int {
        UserRole.roleOrder[type] ?? 999
    }
}

struct RoleRequest: Decodable, Identifiable, Hashable {
    let id: String
    let userId: String
    let userName: String?
    let userDisplayName: String?
    let userEmail: String?
    let roleType: String
    let requestedRole: String
    let groupId: Int?
    let groupName: String?
    let message: String?
    let comment: String?
    let status: String
    let createdAt: String
    let reviewedAt: String?
    let reviewComment: String?

    private enum CodingKeys: String, CodingKey {
        case id
        case userId
        case snakeUserId = "user_id"
        case userName
        case snakeUserName = "user_name"
        case userDisplayName
        case displayName
        case userEmail
        case snakeUserEmail = "user_email"
        case email
        case roleType
        case snakeRoleType = "role_type"
        case requestedRole
        case snakeRequestedRole = "requested_role"
        case groupId
        case snakeGroupId = "group_id"
        case groupName
        case snakeGroupName = "group_name"
        case message
        case comment
        case status
        case createdAt
        case snakeCreatedAt = "created_at"
        case reviewedAt
        case snakeReviewedAt = "reviewed_at"
        case reviewComment
        case snakeReviewComment = "review_comment"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let stringId = try? container.decode(String.self, forKey: .id) {
            id = stringId
        } else {
            id = String(try container.decode(Int.self, forKey: .id))
        }
        if let stringUserId = try? container.decode(String.self, forKey: .userId) {
            userId = stringUserId
        } else if let stringUserId = try? container.decode(String.self, forKey: .snakeUserId) {
            userId = stringUserId
        } else if let intUserId = try? container.decode(Int.self, forKey: .userId) {
            userId = String(intUserId)
        } else {
            userId = String(try container.decode(Int.self, forKey: .snakeUserId))
        }
        userName = try container.decodeIfPresent(String.self, forKey: .userName)
            ?? container.decodeIfPresent(String.self, forKey: .snakeUserName)
        userDisplayName = try container.decodeIfPresent(String.self, forKey: .userDisplayName)
            ?? container.decodeIfPresent(String.self, forKey: .displayName)
            ?? userName
        userEmail = try container.decodeIfPresent(String.self, forKey: .userEmail)
            ?? container.decodeIfPresent(String.self, forKey: .snakeUserEmail)
            ?? container.decodeIfPresent(String.self, forKey: .email)
        roleType = try container.decodeIfPresent(String.self, forKey: .roleType)
            ?? container.decodeIfPresent(String.self, forKey: .snakeRoleType)
            ?? container.decodeIfPresent(String.self, forKey: .requestedRole)
            ?? container.decode(String.self, forKey: .snakeRequestedRole)
        requestedRole = try container.decodeIfPresent(String.self, forKey: .requestedRole)
            ?? container.decodeIfPresent(String.self, forKey: .snakeRequestedRole)
            ?? roleType
        groupId = try container.decodeIfPresent(Int.self, forKey: .groupId)
            ?? container.decodeIfPresent(Int.self, forKey: .snakeGroupId)
        groupName = try container.decodeIfPresent(String.self, forKey: .groupName)
            ?? container.decodeIfPresent(String.self, forKey: .snakeGroupName)
        message = try container.decodeIfPresent(String.self, forKey: .message)
        comment = try container.decodeIfPresent(String.self, forKey: .comment)
        status = try container.decodeIfPresent(String.self, forKey: .status) ?? ""
        createdAt = try container.decodeIfPresent(String.self, forKey: .createdAt)
            ?? container.decodeIfPresent(String.self, forKey: .snakeCreatedAt)
            ?? ""
        reviewedAt = try container.decodeIfPresent(String.self, forKey: .reviewedAt)
            ?? container.decodeIfPresent(String.self, forKey: .snakeReviewedAt)
        reviewComment = try container.decodeIfPresent(String.self, forKey: .reviewComment)
            ?? container.decodeIfPresent(String.self, forKey: .snakeReviewComment)
    }
}

struct RoleRequestCreateRequest: Encodable {
    let roleType: String
    let groupId: Int?
    let groupName: String?
    let comment: String?
}

struct RoleRequestRejectRequest: Encodable {
    let comment: String?
}

struct GroupChangeRequestCreateRequest: Encodable {
    let requestedGroupId: Int
    let requestedGroupName: String?
    let comment: String?
}

struct GroupChangeRequestReviewRequest: Encodable {
    let comment: String?
}

struct GroupChangeRequestDTO: Decodable, Identifiable, Hashable {
    let id: String
    let userId: String
    let userName: String?
    let userEmail: String?
    let currentGroupId: Int?
    let currentGroupName: String?
    let requestedGroupId: Int
    let requestedGroupName: String?
    let comment: String?
    let status: String
    let reviewedByAdminEmail: String?
    let reviewComment: String?
    let createdAt: String
    let reviewedAt: String?

    private enum CodingKeys: String, CodingKey {
        case id
        case userId
        case snakeUserId = "user_id"
        case userName
        case snakeUserName = "user_name"
        case userEmail
        case snakeUserEmail = "user_email"
        case currentGroupId
        case snakeCurrentGroupId = "current_group_id"
        case currentGroupName
        case snakeCurrentGroupName = "current_group_name"
        case requestedGroupId
        case snakeRequestedGroupId = "requested_group_id"
        case requestedGroupName
        case snakeRequestedGroupName = "requested_group_name"
        case comment
        case status
        case reviewedByAdminEmail
        case snakeReviewedByAdminEmail = "reviewed_by_admin_email"
        case reviewComment
        case snakeReviewComment = "review_comment"
        case createdAt
        case snakeCreatedAt = "created_at"
        case reviewedAt
        case snakeReviewedAt = "reviewed_at"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let stringId = try? container.decode(String.self, forKey: .id) {
            id = stringId
        } else {
            id = String(try container.decode(Int.self, forKey: .id))
        }
        if let stringUserId = try? container.decode(String.self, forKey: .userId) {
            userId = stringUserId
        } else if let intUserId = try? container.decode(Int.self, forKey: .userId) {
            userId = String(intUserId)
        } else if let stringUserId = try? container.decode(String.self, forKey: .snakeUserId) {
            userId = stringUserId
        } else {
            userId = String(try container.decode(Int.self, forKey: .snakeUserId))
        }
        userName = try container.decodeIfPresent(String.self, forKey: .userName)
            ?? container.decodeIfPresent(String.self, forKey: .snakeUserName)
        userEmail = try container.decodeIfPresent(String.self, forKey: .userEmail)
            ?? container.decodeIfPresent(String.self, forKey: .snakeUserEmail)
        currentGroupId = try container.decodeIfPresent(Int.self, forKey: .currentGroupId)
            ?? container.decodeIfPresent(Int.self, forKey: .snakeCurrentGroupId)
        currentGroupName = try container.decodeIfPresent(String.self, forKey: .currentGroupName)
            ?? container.decodeIfPresent(String.self, forKey: .snakeCurrentGroupName)
        requestedGroupId = try container.decodeIfPresent(Int.self, forKey: .requestedGroupId)
            ?? container.decode(Int.self, forKey: .snakeRequestedGroupId)
        requestedGroupName = try container.decodeIfPresent(String.self, forKey: .requestedGroupName)
            ?? container.decodeIfPresent(String.self, forKey: .snakeRequestedGroupName)
        comment = try container.decodeIfPresent(String.self, forKey: .comment)
        status = try container.decodeIfPresent(String.self, forKey: .status) ?? ""
        reviewedByAdminEmail = try container.decodeIfPresent(String.self, forKey: .reviewedByAdminEmail)
            ?? container.decodeIfPresent(String.self, forKey: .snakeReviewedByAdminEmail)
        reviewComment = try container.decodeIfPresent(String.self, forKey: .reviewComment)
            ?? container.decodeIfPresent(String.self, forKey: .snakeReviewComment)
        createdAt = try container.decodeIfPresent(String.self, forKey: .createdAt)
            ?? container.decodeIfPresent(String.self, forKey: .snakeCreatedAt)
            ?? ""
        reviewedAt = try container.decodeIfPresent(String.self, forKey: .reviewedAt)
            ?? container.decodeIfPresent(String.self, forKey: .snakeReviewedAt)
    }
}

struct RoleRequestDTO: Decodable, Identifiable, Hashable {
    let id: String
    let requestedRole: String
    let message: String?
    let status: String
    let createdAt: String
    let reviewedAt: String?
    let reviewComment: String?
    let userEmail: String?
    let userName: String?

    private enum CodingKeys: String, CodingKey {
        case id
        case requestedRole
        case snakeRequestedRole = "requested_role"
        case role
        case message
        case status
        case createdAt
        case snakeCreatedAt = "created_at"
        case reviewedAt
        case snakeReviewedAt = "reviewed_at"
        case reviewComment
        case snakeReviewComment = "review_comment"
        case userEmail
        case snakeUserEmail = "user_email"
        case email
        case userName
        case snakeUserName = "user_name"
        case name
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let stringId = try? container.decode(String.self, forKey: .id) {
            id = stringId
        } else {
            id = String(try container.decode(Int.self, forKey: .id))
        }
        requestedRole = try container.decodeIfPresent(String.self, forKey: .requestedRole)
            ?? container.decodeIfPresent(String.self, forKey: .snakeRequestedRole)
            ?? container.decodeIfPresent(String.self, forKey: .role)
            ?? ""
        message = try container.decodeIfPresent(String.self, forKey: .message)
        status = try container.decodeIfPresent(String.self, forKey: .status) ?? ""
        createdAt = try container.decodeIfPresent(String.self, forKey: .createdAt)
            ?? container.decodeIfPresent(String.self, forKey: .snakeCreatedAt)
            ?? ""
        reviewedAt = try container.decodeIfPresent(String.self, forKey: .reviewedAt)
            ?? container.decodeIfPresent(String.self, forKey: .snakeReviewedAt)
        reviewComment = try container.decodeIfPresent(String.self, forKey: .reviewComment)
            ?? container.decodeIfPresent(String.self, forKey: .snakeReviewComment)
        userEmail = try container.decodeIfPresent(String.self, forKey: .userEmail)
            ?? container.decodeIfPresent(String.self, forKey: .snakeUserEmail)
            ?? container.decodeIfPresent(String.self, forKey: .email)
        userName = try container.decodeIfPresent(String.self, forKey: .userName)
            ?? container.decodeIfPresent(String.self, forKey: .snakeUserName)
            ?? container.decodeIfPresent(String.self, forKey: .name)
    }
}

struct RoleRequestCreateDTO: Encodable {
    let role: String
    let message: String
}

struct AdminUserDTO: Decodable, Identifiable, Equatable {
    let id: String
    let email: String?
    let name: String?
    let roles: [UserRole]
    let tier: String
    let remainingToday: Int
    let pendingRoleRequests: [RoleRequestDTO]
    let badges: [UserBadge]

    var displayName: String {
        let trimmedName = name?.mympsuTrimmed ?? ""
        if !trimmedName.isEmpty { return trimmedName }

        let trimmedEmail = email?.mympsuTrimmed ?? ""
        if !trimmedEmail.isEmpty { return trimmedEmail }

        return "Пользователь"
    }

    var remainingTodayText: String {
        remainingToday == -1 ? "∞" : String(remainingToday)
    }

    var normalizedEmail: String? {
        let value = email?.mympsuTrimmed.lowercased()
        return value?.isEmpty == false ? value : nil
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case email
        case name
        case roles
        case tier
        case remainingToday
        case snakeRemainingToday = "remaining_today"
        case pendingRoleRequests
        case snakePendingRoleRequests = "pending_role_requests"
        case badges
    }

    init(
        id: String,
        email: String?,
        name: String?,
        roles: [UserRole],
        tier: String,
        remainingToday: Int,
        pendingRoleRequests: [RoleRequestDTO] = [],
        badges: [UserBadge] = []
    ) {
        self.id = id
        self.email = email
        self.name = name
        self.roles = roles
        self.tier = tier
        self.remainingToday = remainingToday
        self.pendingRoleRequests = pendingRoleRequests
        self.badges = badges
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        email = try container.decodeIfPresent(String.self, forKey: .email)
        name = try container.decodeIfPresent(String.self, forKey: .name)
        roles = try container.decodeIfPresent([UserRole].self, forKey: .roles) ?? []
        tier = try container.decodeIfPresent(String.self, forKey: .tier) ?? "free"
        remainingToday = try container.decodeIfPresent(Int.self, forKey: .remainingToday)
            ?? container.decodeIfPresent(Int.self, forKey: .snakeRemainingToday)
            ?? 0
        pendingRoleRequests = try container.decodeIfPresent([RoleRequestDTO].self, forKey: .pendingRoleRequests)
            ?? container.decodeIfPresent([RoleRequestDTO].self, forKey: .snakePendingRoleRequests)
            ?? []
        badges = try container.decodeIfPresent([UserBadge].self, forKey: .badges) ?? []
    }

    var roleTypes: Set<String> {
        Set(roles.map(\.type))
    }

    var sortedRoles: [UserRole] {
        roles.sorted { lhs, rhs in
            let lhsPriority = UserRole.roleOrder[lhs.type] ?? 999
            let rhsPriority = UserRole.roleOrder[rhs.type] ?? 999
            if lhsPriority != rhsPriority {
                return lhsPriority < rhsPriority
            }
            return lhs.title.localizedStandardCompare(rhs.title) == .orderedAscending
        }
    }

    var isAdmin: Bool {
        roleTypes.contains("admin")
    }
}

struct GroupUser: Decodable, Identifiable, Equatable {
    let id: String
    let name: String?
    let email: String?
    let groupId: Int?
    let roles: [UserRole]
    let tier: String?
    let badges: [UserBadge]

    private enum CodingKeys: String, CodingKey {
        case id
        case name
        case email
        case groupId
        case snakeGroupId = "group_id"
        case roles
        case tier
        case badges
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decodeIfPresent(String.self, forKey: .name)
        email = try container.decodeIfPresent(String.self, forKey: .email)
        groupId = try container.decodeIfPresent(Int.self, forKey: .groupId)
            ?? container.decodeIfPresent(Int.self, forKey: .snakeGroupId)
        roles = try container.decodeIfPresent([UserRole].self, forKey: .roles) ?? []
        tier = try container.decodeIfPresent(String.self, forKey: .tier)
        badges = try container.decodeIfPresent([UserBadge].self, forKey: .badges) ?? []
    }

    var displayName: String {
        let trimmedName = name?.mympsuTrimmed ?? ""
        if !trimmedName.isEmpty { return trimmedName }

        let trimmedEmail = email?.mympsuTrimmed ?? ""
        if !trimmedEmail.isEmpty { return trimmedEmail }

        return "Пользователь"
    }

    var sortedRoles: [UserRole] {
        roles.sorted { lhs, rhs in
            let lhsPriority = UserRole.roleOrder[lhs.type] ?? 999
            let rhsPriority = UserRole.roleOrder[rhs.type] ?? 999
            if lhsPriority != rhsPriority {
                return lhsPriority < rhsPriority
            }
            return lhs.title.localizedStandardCompare(rhs.title) == .orderedAscending
        }
    }
}

struct Homework: Codable, Identifiable, Equatable {
    let id: String
    let groupId: Int
    let lessonDate: String
    let lessonTime: String
    let subject: String
    let teacher: String?
    let room: String?
    let text: String
    let createdBy: String?
    let createdAt: String?
    let updatedAt: String?

    enum CodingKeys: String, CodingKey {
        case id
        case groupId = "group_id"
        case lessonDate = "lesson_date"
        case lessonTime = "lesson_time"
        case subject
        case teacher
        case room
        case text
        case createdBy = "created_by"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

struct HomeworkMutationRequest: Encodable {
    let lessonDate: String
    let lessonTime: String
    let subject: String
    let teacher: String?
    let room: String?
    let text: String

    enum CodingKeys: String, CodingKey {
        case lessonDate = "lesson_date"
        case lessonTime = "lesson_time"
        case subject
        case teacher
        case room
        case text
    }
}

struct HomeworkUpdateRequest: Encodable {
    let text: String
}

struct AssignUserGroupRequest: Encodable {
    let groupId: Int

    enum CodingKeys: String, CodingKey {
        case groupId = "group_id"
    }
}

struct RoleMutationRequest: Encodable {
    let userId: String
    let role: String

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case role
    }
}

struct BadgeMutationRequest: Encodable {
    let badgeCode: String
    let note: String?

    enum CodingKeys: String, CodingKey {
        case badgeCode = "badge_code"
        case note
    }
}

struct UserSettings: Codable, Equatable {
    let selectedGroupId: Int?
    let selectedGroupName: String?
    let scheduleCacheWeeks: Int
    let liveActivityEnabled: Bool

    init(
        selectedGroupId: Int?,
        selectedGroupName: String?,
        scheduleCacheWeeks: Int = UserSettings.defaultScheduleCacheWeeks,
        liveActivityEnabled: Bool = UserSettings.defaultLiveActivityEnabled
    ) {
        self.selectedGroupId = selectedGroupId
        self.selectedGroupName = selectedGroupName
        self.scheduleCacheWeeks = min(max(scheduleCacheWeeks, 0), 4)
        self.liveActivityEnabled = liveActivityEnabled
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        selectedGroupId = try container.decodeIfPresent(Int.self, forKey: .selectedGroupId)
            ?? container.decodeIfPresent(Int.self, forKey: .snakeSelectedGroupId)
        selectedGroupName = try container.decodeIfPresent(String.self, forKey: .selectedGroupName)
            ?? container.decodeIfPresent(String.self, forKey: .snakeSelectedGroupName)
        let decodedWeeks = try container.decodeIfPresent(Int.self, forKey: .scheduleCacheWeeks)
            ?? container.decodeIfPresent(Int.self, forKey: .snakeScheduleCacheWeeks)
            ?? Self.defaultScheduleCacheWeeks
        scheduleCacheWeeks = min(max(decodedWeeks, 0), 4)
        liveActivityEnabled = try container.decodeIfPresent(Bool.self, forKey: .liveActivityEnabled)
            ?? container.decodeIfPresent(Bool.self, forKey: .snakeLiveActivityEnabled)
            ?? Self.defaultLiveActivityEnabled
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(selectedGroupId, forKey: .selectedGroupId)
        try container.encodeIfPresent(selectedGroupName, forKey: .selectedGroupName)
        try container.encode(scheduleCacheWeeks, forKey: .scheduleCacheWeeks)
        try container.encode(liveActivityEnabled, forKey: .liveActivityEnabled)
    }

    private static let defaultScheduleCacheWeeks = 1
    private static let defaultLiveActivityEnabled = true

    private enum CodingKeys: String, CodingKey {
        case selectedGroupId
        case selectedGroupName
        case scheduleCacheWeeks
        case liveActivityEnabled
        case snakeSelectedGroupId = "selected_group_id"
        case snakeSelectedGroupName = "selected_group_name"
        case snakeScheduleCacheWeeks = "schedule_cache_weeks"
        case snakeLiveActivityEnabled = "live_activity_enabled"
    }
}
