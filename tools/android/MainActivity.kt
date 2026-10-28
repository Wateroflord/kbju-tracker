package com.kbju.kbju_tracker

import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

// FlutterFragmentActivity нужен для Health Connect.
class MainActivity : FlutterFragmentActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "kbju/steps").setMethodCallHandler { call, result ->
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
    }
}
