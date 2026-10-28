package com.kbju.kbju_tracker

import android.app.Activity
import android.content.ActivityNotFoundException
import android.content.Intent
import android.speech.RecognizerIntent
import android.speech.tts.TextToSpeech
import android.view.WindowManager
import androidx.activity.result.contract.ActivityResultContracts
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.Locale

// FlutterFragmentActivity нужен для Health Connect.
class MainActivity : FlutterFragmentActivity() {
    private var tts: TextToSpeech? = null
    private var ttsReady = false
    private var pending: Pair<String, String>? = null

    // Голосовой ввод: окно распознавания речи Google.
    private var speechResult: MethodChannel.Result? = null
    private val speechLauncher = registerForActivityResult(ActivityResultContracts.StartActivityForResult()) { res ->
        val r = speechResult
        speechResult = null
        if (r != null) {
            if (res.resultCode == Activity.RESULT_OK) {
                val list = res.data?.getStringArrayListExtra(RecognizerIntent.EXTRA_RESULTS)
                r.success(list?.firstOrNull())
            } else {
                r.success(null)
            }
        }
    }

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

        MethodChannel(messenger, "kbju/speech").setMethodCallHandler { call, result ->
            when (call.method) {
                "listen" -> {
                    val lang = call.argument<String>("lang") ?: "ru-RU"
                    val prompt = call.argument<String>("prompt") ?: ""
                    val intent = Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH).apply {
                        putExtra(RecognizerIntent.EXTRA_LANGUAGE_MODEL, RecognizerIntent.LANGUAGE_MODEL_FREE_FORM)
                        putExtra(RecognizerIntent.EXTRA_LANGUAGE, lang)
                        putExtra(RecognizerIntent.EXTRA_LANGUAGE_PREFERENCE, lang)
                        putExtra(RecognizerIntent.EXTRA_MAX_RESULTS, 1)
                        if (prompt.isNotEmpty()) putExtra(RecognizerIntent.EXTRA_PROMPT, prompt)
                    }
                    speechResult?.success(null)
                    speechResult = result
                    try {
                        speechLauncher.launch(intent)
                    } catch (e: ActivityNotFoundException) {
                        speechResult = null
                        result.error("unavailable", "No speech recognizer", null)
                    }
                }
                else -> result.notImplemented()
            }
        }

        // Виджет на главном экране.
        MethodChannel(messenger, "kbju/widget").setMethodCallHandler { call, result ->
            when (call.method) {
                "update" -> {
                    val args = call.arguments as? Map<*, *>
                    if (args != null) {
                        KbjuWidget.save(this, args.entries.associate { it.key.toString() to it.value })
                    }
                    KbjuWidget.updateAll(this)
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }

        // Не гасить экран во время таймеров (разминка, дыхание).
        MethodChannel(messenger, "kbju/screen").setMethodCallHandler { call, result ->
            when (call.method) {
                "keepOn" -> {
                    val on = call.argument<Boolean>("on") ?: false
                    runOnUiThread {
                        if (on) window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
                        else window.clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
                    }
                    result.success(true)
                }
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
