package dev.safe.safe

import android.content.ActivityNotFoundException
import android.content.ClipData
import android.content.ClipDescription
import android.content.ClipboardManager
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.PersistableBundle
import android.provider.OpenableColumns
import android.view.WindowManager
import java.io.IOException
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    /**
     * L'enregistrement en cours, s'il y en a un.
     *
     * `ACTION_CREATE_DOCUMENT` rend la main par `onActivityResult`, bien après
     * l'appel Flutter: il faut donc garder de quoi répondre. `FlutterActivity`
     * hérite d'`Activity` et non de `ComponentActivity`, si bien que
     * `registerForActivityResult` n'est pas disponible ici.
     */
    private var pendingSave: MethodChannel.Result? = null
    private var pendingBytes: ByteArray? = null

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

        MethodChannel(messenger, "dev.safe/save").setMethodCallHandler { call, result ->
            when (call.method) {
                "createDocument" -> startCreateDocument(call.argument("name"), call.argument("bytes"), result)
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

    /**
     * Ouvre le sélecteur d'enregistrement du système.
     *
     * Partager n'est pas enregistrer: une sauvegarde de coffre doit pouvoir
     * atterrir dans un dossier choisi, sans passer par une autre application.
     * Les octets sont déjà chiffrés — ce sont ceux du fichier de coffre — donc
     * les tenir en mémoire le temps du sélecteur n'expose rien.
     */
    private fun startCreateDocument(name: String?, bytes: ByteArray?, result: MethodChannel.Result) {
        if (bytes == null) {
            result.error("argument", "octets manquants", null)
            return
        }
        if (pendingSave != null) {
            result.error("occupe", "un enregistrement est déjà en cours", null)
            return
        }
        val intent = Intent(Intent.ACTION_CREATE_DOCUMENT).apply {
            addCategory(Intent.CATEGORY_OPENABLE)
            type = "application/octet-stream"
            putExtra(Intent.EXTRA_TITLE, name ?: "vault.safe")
        }
        pendingSave = result
        pendingBytes = bytes
        try {
            startActivityForResult(intent, SAVE_REQUEST)
        } catch (e: ActivityNotFoundException) {
            pendingSave = null
            pendingBytes = null
            result.error("indisponible", "aucun sélecteur de fichiers sur cet appareil", null)
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        if (requestCode != SAVE_REQUEST) {
            super.onActivityResult(requestCode, resultCode, data)
            return
        }
        val result = pendingSave
        val bytes = pendingBytes
        pendingSave = null
        pendingBytes = null
        // L'activité a pu être recréée pendant que le sélecteur était ouvert:
        // il n'y a alors plus personne à qui répondre, et se taire vaut mieux
        // que planter.
        if (result == null || bytes == null) {
            return
        }
        val target = if (resultCode == RESULT_OK) data?.data else null
        if (target == null) {
            // Renoncé. `null` et non une erreur: l'écran ne doit pas annoncer
            // un export qui n'a pas eu lieu, ni une panne qui n'existe pas.
            result.success(null)
            return
        }
        try {
            val stream = contentResolver.openOutputStream(target)
                ?: throw IOException("flux d'écriture indisponible")
            stream.use { it.write(bytes) }
            result.success(displayName(target))
        } catch (e: Exception) {
            result.error("ecriture", e.message ?: "écriture impossible", null)
        }
    }

    /** Le nom que le système a retenu, pour pouvoir le dire à l'utilisateur. */
    private fun displayName(uri: Uri): String {
        contentResolver.query(uri, arrayOf(OpenableColumns.DISPLAY_NAME), null, null, null)
            ?.use { cursor ->
                if (cursor.moveToFirst() && !cursor.isNull(0)) {
                    return cursor.getString(0)
                }
            }
        return uri.lastPathSegment ?: "vault.safe"
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

    private companion object {
        /** Choisi loin des codes des greffons, qui partent de zéro. */
        const val SAVE_REQUEST = 0x5AFE
    }
}
