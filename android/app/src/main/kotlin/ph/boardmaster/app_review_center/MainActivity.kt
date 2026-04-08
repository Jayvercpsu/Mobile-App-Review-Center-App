package ph.boardmaster.app_review_center

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.view.WindowManager

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "ph.boardmaster.app_review_center/screen_security",
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "enableSecure" -> {
                    runOnUiThread {
                        window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
                        result.success(true)
                    }
                }
                "disableSecure" -> {
                    runOnUiThread {
                        window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
                        result.success(true)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }
}
