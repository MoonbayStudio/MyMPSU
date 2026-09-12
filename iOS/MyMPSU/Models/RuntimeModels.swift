import Foundation

struct PublicConfig: Decodable, Equatable {
    let settings: RuntimeSettings

    static let `default` = PublicConfig(settings: .default)
}

struct RuntimeSettings: Decodable, Equatable {
    let aiEnabled: Bool
    let aiDailyLimit: Int
    let personaTheme: String
    let maintenanceMode: Bool
    let scheduleCacheTTLSeconds: Int

    static let `default` = RuntimeSettings(
        aiEnabled: true,
        aiDailyLimit: 0,
        personaTheme: "auto",
        maintenanceMode: false,
        scheduleCacheTTLSeconds: 300
    )

    private enum CodingKeys: String, CodingKey {
        case aiEnabled = "AI_ENABLED"
        case aiDailyLimit = "AI_DAILY_LIMIT"
        case personaTheme = "PERSONA_THEME"
        case maintenanceMode = "MAINTENANCE_MODE"
        case scheduleCacheTTLSeconds = "SCHEDULE_CACHE_TTL_SECONDS"
    }

    init(
        aiEnabled: Bool,
        aiDailyLimit: Int,
        personaTheme: String,
        maintenanceMode: Bool,
        scheduleCacheTTLSeconds: Int
    ) {
        self.aiEnabled = aiEnabled
        self.aiDailyLimit = max(0, aiDailyLimit)
        self.personaTheme = personaTheme.isEmpty ? "auto" : personaTheme
        self.maintenanceMode = maintenanceMode
        self.scheduleCacheTTLSeconds = max(0, scheduleCacheTTLSeconds)
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            aiEnabled: try container.decodeIfPresent(Bool.self, forKey: .aiEnabled) ?? Self.default.aiEnabled,
            aiDailyLimit: try container.decodeIfPresent(Int.self, forKey: .aiDailyLimit) ?? Self.default.aiDailyLimit,
            personaTheme: try container.decodeIfPresent(String.self, forKey: .personaTheme) ?? Self.default.personaTheme,
            maintenanceMode: try container.decodeIfPresent(Bool.self, forKey: .maintenanceMode) ?? Self.default.maintenanceMode,
            scheduleCacheTTLSeconds: try container.decodeIfPresent(Int.self, forKey: .scheduleCacheTTLSeconds) ?? Self.default.scheduleCacheTTLSeconds
        )
    }
}

enum SystemNoticeType: String, Codable, CaseIterable, Identifiable {
    case info
    case warning
    case maintenance
    case critical

    var id: String { rawValue }

    var title: String {
        switch self {
        case .info: return "Информация"
        case .warning: return "Предупреждение"
        case .maintenance: return "Техработы"
        case .critical: return "Важно"
        }
    }
}

enum SystemNoticePresentation: String, Codable, CaseIterable, Identifiable {
    case banner
    case modal

    var id: String { rawValue }

    var title: String {
        switch self {
        case .banner: return "Баннер"
        case .modal: return "Модальное окно"
        }
    }
}

struct SystemNotice: Codable, Identifiable, Equatable, Hashable {
    let id: Int
    var title: String
    var message: String
    var type: SystemNoticeType
    var showAs: SystemNoticePresentation
    var dismissible: Bool
    var startsAt: String?
    var endsAt: String?
    var isActive: Bool?

    private enum CodingKeys: String, CodingKey {
        case id
        case title
        case message
        case type
        case showAs
        case snakeShowAs = "show_as"
        case dismissible
        case startsAt
        case snakeStartsAt = "starts_at"
        case endsAt
        case snakeEndsAt = "ends_at"
        case isActive
        case snakeIsActive = "is_active"
    }

    init(
        id: Int,
        title: String,
        message: String,
        type: SystemNoticeType,
        showAs: SystemNoticePresentation,
        dismissible: Bool,
        startsAt: String? = nil,
        endsAt: String? = nil,
        isActive: Bool? = nil
    ) {
        self.id = id
        self.title = title
        self.message = message
        self.type = type
        self.showAs = showAs
        self.dismissible = dismissible
        self.startsAt = startsAt
        self.endsAt = endsAt
        self.isActive = isActive
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int.self, forKey: .id)
        title = try container.decodeIfPresent(String.self, forKey: .title) ?? "Уведомление"
        message = try container.decodeIfPresent(String.self, forKey: .message) ?? ""
        type = try container.decodeIfPresent(SystemNoticeType.self, forKey: .type) ?? .info
        showAs = try container.decodeIfPresent(SystemNoticePresentation.self, forKey: .showAs)
            ?? container.decodeIfPresent(SystemNoticePresentation.self, forKey: .snakeShowAs)
            ?? .banner
        dismissible = try container.decodeIfPresent(Bool.self, forKey: .dismissible) ?? true
        startsAt = try container.decodeIfPresent(String.self, forKey: .startsAt)
            ?? container.decodeIfPresent(String.self, forKey: .snakeStartsAt)
        endsAt = try container.decodeIfPresent(String.self, forKey: .endsAt)
            ?? container.decodeIfPresent(String.self, forKey: .snakeEndsAt)
        isActive = try container.decodeIfPresent(Bool.self, forKey: .isActive)
            ?? container.decodeIfPresent(Bool.self, forKey: .snakeIsActive)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(title, forKey: .title)
        try container.encode(message, forKey: .message)
        try container.encode(type, forKey: .type)
        try container.encode(showAs, forKey: .showAs)
        try container.encode(dismissible, forKey: .dismissible)
        try container.encodeIfPresent(startsAt, forKey: .startsAt)
        try container.encodeIfPresent(endsAt, forKey: .endsAt)
        try container.encodeIfPresent(isActive, forKey: .isActive)
    }
}

struct SystemNoticeResponse: Decodable, Equatable {
    let isActive: Bool
    let notice: SystemNotice?
}

struct AccountSession: Decodable, Identifiable, Equatable, Hashable {
    let id: String
    let deviceId: String?
    let deviceName: String?
    let platform: String?
    let appVersion: String?
    let ipAddress: String?
    let maskedIp: String?
    let userAgent: String?
    let createdAt: String?
    let lastSeenAt: String?
    let revokedAt: String?
    let isCurrent: Bool

    private enum CodingKeys: String, CodingKey {
        case id
        case sessionId = "session_id"
        case deviceId
        case snakeDeviceId = "device_id"
        case deviceName
        case snakeDeviceName = "device_name"
        case platform
        case appVersion
        case snakeAppVersion = "app_version"
        case ipAddress
        case snakeIpAddress = "ip_address"
        case maskedIp
        case snakeMaskedIp = "masked_ip"
        case userAgent
        case snakeUserAgent = "user_agent"
        case createdAt
        case snakeCreatedAt = "created_at"
        case lastSeenAt
        case snakeLastSeenAt = "last_seen_at"
        case revokedAt
        case snakeRevokedAt = "revoked_at"
        case isCurrent
        case snakeIsCurrent = "is_current"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let intId = try? container.decodeIfPresent(Int.self, forKey: .id) {
            self.id = String(intId)
        } else if let intId = try? container.decodeIfPresent(Int.self, forKey: .sessionId) {
            self.id = String(intId)
        } else if let id = try? container.decodeIfPresent(String.self, forKey: .id) {
            self.id = id
        } else if let id = try? container.decodeIfPresent(String.self, forKey: .sessionId) {
            self.id = id
        } else {
            throw DecodingError.keyNotFound(CodingKeys.id, DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Missing session id"))
        }
        deviceId = try container.decodeIfPresent(String.self, forKey: .deviceId)
            ?? container.decodeIfPresent(String.self, forKey: .snakeDeviceId)
        deviceName = try container.decodeIfPresent(String.self, forKey: .deviceName)
            ?? container.decodeIfPresent(String.self, forKey: .snakeDeviceName)
        platform = try container.decodeIfPresent(String.self, forKey: .platform)
        appVersion = try container.decodeIfPresent(String.self, forKey: .appVersion)
            ?? container.decodeIfPresent(String.self, forKey: .snakeAppVersion)
        ipAddress = try container.decodeIfPresent(String.self, forKey: .ipAddress)
            ?? container.decodeIfPresent(String.self, forKey: .snakeIpAddress)
        maskedIp = try container.decodeIfPresent(String.self, forKey: .maskedIp)
            ?? container.decodeIfPresent(String.self, forKey: .snakeMaskedIp)
        userAgent = try container.decodeIfPresent(String.self, forKey: .userAgent)
            ?? container.decodeIfPresent(String.self, forKey: .snakeUserAgent)
        createdAt = try container.decodeIfPresent(String.self, forKey: .createdAt)
            ?? container.decodeIfPresent(String.self, forKey: .snakeCreatedAt)
        lastSeenAt = try container.decodeIfPresent(String.self, forKey: .lastSeenAt)
            ?? container.decodeIfPresent(String.self, forKey: .snakeLastSeenAt)
        revokedAt = try container.decodeIfPresent(String.self, forKey: .revokedAt)
            ?? container.decodeIfPresent(String.self, forKey: .snakeRevokedAt)
        isCurrent = try container.decodeIfPresent(Bool.self, forKey: .isCurrent)
            ?? container.decodeIfPresent(Bool.self, forKey: .snakeIsCurrent)
            ?? false
    }

    var isRevoked: Bool {
        revokedAt?.mympsuTrimmed.isEmpty == false
    }

    var safeIpText: String? {
        if let maskedIp, !maskedIp.mympsuTrimmed.isEmpty {
            return maskedIp
        }
        guard let ipAddress, !ipAddress.mympsuTrimmed.isEmpty else { return nil }
        if ipAddress.contains(":") {
            return "IPv6 скрыт"
        }
        let parts = ipAddress.split(separator: ".")
        guard parts.count == 4 else { return "IP скрыт" }
        return "\(parts[0]).\(parts[1]).***.***"
    }
}

enum RuntimeSettingValue: Codable, Equatable, Hashable {
    case bool(Bool)
    case int(Int)
    case string(String)

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let bool = try? container.decode(Bool.self) {
            self = .bool(bool)
        } else if let int = try? container.decode(Int.self) {
            self = .int(int)
        } else {
            self = .string((try? container.decode(String.self)) ?? "")
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .bool(let value): try container.encode(value)
        case .int(let value): try container.encode(value)
        case .string(let value): try container.encode(value)
        }
    }

    var displayText: String {
        switch self {
        case .bool(let value): return value ? "Включено" : "Выключено"
        case .int(let value): return String(max(0, value))
        case .string(let value): return value
        }
    }
}

struct AdminRuntimeSetting: Decodable, Identifiable, Equatable, Hashable {
    let key: String
    var value: RuntimeSettingValue

    var id: String { key }

    private enum CodingKeys: String, CodingKey {
        case key
        case value
    }

    init(key: String, value: RuntimeSettingValue) {
        self.key = key
        self.value = value
    }
}

struct AdminRuntimeSettingsResponse: Decodable {
    let settings: [AdminRuntimeSetting]

    init(from decoder: Decoder) throws {
        if let array = try? [AdminRuntimeSetting](from: decoder) {
            settings = array
            return
        }

        let container = try decoder.container(keyedBy: DynamicCodingKey.self)
        if container.contains(DynamicCodingKey("settings")) {
            if let array = try? container.decode([AdminRuntimeSetting].self, forKey: DynamicCodingKey("settings")) {
                settings = array
                return
            }
            let dictionary = try container.decode([String: RuntimeSettingValue].self, forKey: DynamicCodingKey("settings"))
            settings = dictionary.map { AdminRuntimeSetting(key: $0.key, value: $0.value) }
                .sorted { $0.key < $1.key }
            return
        }

        let dictionary = try [String: RuntimeSettingValue](from: decoder)
        settings = dictionary.map { AdminRuntimeSetting(key: $0.key, value: $0.value) }
            .sorted { $0.key < $1.key }
    }
}

struct RuntimeSettingPatchRequest: Encodable {
    let value: RuntimeSettingValue
}

struct SystemNoticeMutationRequest: Encodable {
    let title: String
    let message: String
    let type: SystemNoticeType
    let showAs: SystemNoticePresentation
    let dismissible: Bool
    let startsAt: String?
    let endsAt: String?

    private enum CodingKeys: String, CodingKey {
        case title
        case message
        case type
        case showAs
        case dismissible
        case startsAt
        case endsAt
    }
}

private struct DynamicCodingKey: CodingKey {
    let stringValue: String
    let intValue: Int? = nil

    init(_ stringValue: String) {
        self.stringValue = stringValue
    }

    init?(stringValue: String) {
        self.stringValue = stringValue
    }

    init?(intValue: Int) {
        return nil
    }
}
