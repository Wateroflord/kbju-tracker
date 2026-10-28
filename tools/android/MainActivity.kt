package com.kbju.kbju_tracker

import android.speech.tts.TextToSpeech
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.Locale

// FlutterFragmentActivity нужен для Health Connect.
class MainActivity : FlutterFragmentActivity() {
    private var tts: TextToSpeech? = null
    private var ttsReady = false
    private var pending: Pair<String, String>? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val messenger = flutterEngine.dartExecutor.binaryMessenger

        MethodChannel(messenger, "kbju/steps").setMethodCallHandler { call, result ->
            when (call.method) {
                "start" -> {
                    StepStore.setEnabled(this, true)
                    StepService.start(this)
                    result.success(true)
                }
                "stop" -> {
                    StepStore.setEnabled(this, false)
                    StepService.stop(this)
                    result.success(true)
                }
                "days" -> result.success(StepStore.daysJson(this))
                "hasSensor" -> result.success(StepService.hasSensor(this))
                "isEnabled" -> result.success(StepStore.isEnabled(this))
                else -> result.notImplemented()
            }
        }

        // Озвучка слов для изучения языков (встроенный синтезатор речи Android).
        MethodChannel(messenger, "kbju/tts").setMethodCallHandler { call, result ->
            when (call.method) {
                "speak" -> {
                    val text = call.argument<String>("text") ?: ""
                    val lang = call.argument<String>("lang") ?: "en-US"
                    result.success(speak(text, lang))
                }
                "stop" -> {
                    tts?.stop()
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }
    }

    /** true — озвучено или поставлено в очередь, false — голос для языка не установлен. */
    private fun speak(text: String, lang: String): Boolean {
        if (tts == null) {
            pending = Pair(text, lang)
            tts = TextToSpeech(this) { status ->
                ttsReady = status == TextToSpeech.SUCCESS
                val p = pending
                pending = null
                if (ttsReady && p != null) doSpeak(p.first, p.second)
            }
            return true
        }
        if (!ttsReady) {
            pending = Pair(text, lang)
            return true
        }
        return doSpeak(text, lang)
    }

    private fun doSpeak(text: String, lang: String): Boolean {
        val engine = tts ?: return false
        val r = engine.setLanguage(Locale.forLanguageTag(lang))
        if (r == TextToSpeech.LANG_MISSING_DATA || r == TextToSpeech.LANG_NOT_SUPPORTED) return false
        engine.setSpeechRate(0.9f)
        engine.speak(text, TextToSpeech.QUEUE_FLUSH, null, "kbju")
        return true
    }

    override fun onDestroy() {
        tts?.shutdown()
        tts = null
        super.onDestroy()
    }
}
