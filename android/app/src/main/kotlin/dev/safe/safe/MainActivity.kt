package dev.safe.safe

import android.os.Bundle
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        // Bloqué dès la création, avant que Flutter ait pu lire les réglages:
        // si l'utilisateur a désactivé l'option, Flutter le dira juste après.
        // L'inverse — partir en non sécurisé — exposerait le contenu pendant
        // le démarrage.
        setSecure(true)
        super.onCreate(savedInstanceState)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "dev.safe/screen",
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "setBlocked" -> {
                    val blocked = call.argument<Boolean>("blocked") ?: true
                    setSecure(blocked)
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun setSecure(secure: Boolean) {
        if (secure) {
            window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
        } else {
            window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
        }
    }
}
