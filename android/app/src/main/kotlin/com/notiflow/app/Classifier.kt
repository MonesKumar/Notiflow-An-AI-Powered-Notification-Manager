package com.notiflow.app

import java.util.Locale

/** Deterministic suggestions, followed by an explicit per-app correction. No trained model. */
object Classifier {
    val categories = setOf("Critical", "Important", "Social", "Promotional")
    private val critical = Regex("\\b(emergency|urgent|fraud|suspicious|security alert|account locked|hospital|ambulance)\\b", RegexOption.IGNORE_CASE)
    private val important = Regex("\\b(exam|semester|assignment|deadline|class cancelled|college|university|payment|paid|debited|credited|transaction|invoice|interview|meeting|salary)\\b", RegexOption.IGNORE_CASE)
    private val promo = Regex("\\b(sale|discount|offer|coupon|cashback|deal|shop now|limited time|promotion|% off)\\b", RegexOption.IGNORE_CASE)
    private val social = Regex("\\b(message|sent you|replied|commented|mentioned|friend request|chat)\\b", RegexOption.IGNORE_CASE)
    private val sensitive = Regex("\\b(otp|one.time (?:passcode|password|code)|verification code|security code|2fa|password reset)\\b|(?<!\\d)\\d{4,8}(?!\\d).{0,35}\\b(code|otp)\\b", RegexOption.IGNORE_CASE)

    fun sanitize(title: String, body: String): Pair<String, String> {
        if (sensitive.containsMatchIn("$title $body")) return "Sensitive notification" to "Content withheld by Notiflow"
        return title.take(160) to body.take(500)
    }
    fun classify(app: String, pkg: String, title: String, body: String, preference: String?): String {
        val content = "$title $body"
        if (critical.containsMatchIn(content)) return "Critical"
        if (preference != null && preference in categories) return preference
        if (important.containsMatchIn(content)) return "Important"
        if (promo.containsMatchIn(content)) return "Promotional"
        if (social.containsMatchIn(content)) return "Social"
        val origin = "$app $pkg".lowercase(Locale.ROOT)
        if (listOf("instagram", "whatsapp", "telegram", "discord", "messenger", "snapchat").any { it in origin }) return "Social"
        if (listOf("shopping", "amazon", "flipkart", "myntra").any { it in origin }) return "Promotional"
        return "Important" // Uncertain items remain visible in the inbox.
    }
}
