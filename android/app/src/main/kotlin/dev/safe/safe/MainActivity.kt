package dev.safe.safe

import android.content.ClipData
import android.content.ClipDescription
import android.content.ClipboardManager
import android.content.Context
import android.os.Build
import android.os.Bundle
import android.os.PersistableBundle
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
        val messenger = flutterEngine.dartExecutor.binaryMessenger

        MethodChannel(messenger, "dev.safe/screen").setMethodCallHandler { call, result ->
            when (call.method) {
                "setBlocked" -> {
                    val blocked = call.argument<Boolean>("blocked") ?: true
                    setSecure(blocked)
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }

        MethodChannel(messenger, "dev.safe/clipboard").setMethodCallHandler { call, result ->
            when (call.method) {
                "copySensitive" -> {
                    val text = call.argument<String>("text")
                    if (text == null) {
                        result.error("argument", "texte manquant", null)
                    } else {
                        copySensitive(text)
                        result.success(null)
                    }
                }
                "clear" -> {
                    clearClipboard()
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

    /**
     * Copie en marquant le contenu comme sensible.
     *
     * `EXTRA_IS_SENSITIVE` demande deux choses distinctes: que le système
     * n'affiche pas la valeur dans son aperçu de copie (Android 13+), et que les
     * claviers ne la rangent pas dans leur historique de presse-papier — un
     * magasin auquel l'application n'a aucun accès, donc qu'elle ne peut pas
     * nettoyer ensuite.
     */
    private fun copySensitive(text: String) {
        val clip = ClipData.newPlainText(null, text)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            clip.description.extras = PersistableBundle().apply {
                putBoolean(ClipDescription.EXTRA_IS_SENSITIVE, true)
            }
        }
        clipboard().setPrimaryClip(clip)
    }

    /**
     * Vide le presse-papier.
     *
     * `clearPrimaryClip` n'existe qu'à partir d'Android 9; avant, écrire une
     * chaîne vide est le seul recours. Aucune vérification préalable du contenu:
     * la lecture échoue quand l'application n'a pas le focus, ce qui est le cas
     * habituel au moment où l'effacement se déclenche.
     */
    private fun clearClipboard() {
        val manager = clipboard()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            manager.clearPrimaryClip()
        } else {
            manager.setPrimaryClip(ClipData.newPlainText(null, ""))
        }
    }

    private fun clipboard() =
        getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager
}
