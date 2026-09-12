package ru.moonbaystudio.mympsu.data.model

import java.util.UUID

data class AssistantMessage(
    val id: String = UUID.randomUUID().toString(),
    val role: Role,
    val text: String,
    val persona: AssistantPersona? = null
) {
    enum class Role {
        USER, ASSISTANT, SYSTEM_LOCAL
    }
}

enum class AssistantPersona(val rawValue: String, val displayName: String, val icon: String) {
    PELIKASHA("pelikasha", "Помощник МПГУ", "bird"),
    STESHA("stesha", "Стеша", "face")
}
