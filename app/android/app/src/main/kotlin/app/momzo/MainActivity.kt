package app.momzo

import android.os.Build
import com.google.ai.edge.aicore.GenerativeModel
import com.google.ai.edge.aicore.generationConfig
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

/**
 * Native bridge for the on-device AI layer (On-Device AI Strategy §3/§4).
 *
 * On-device generation runs Gemini Nano via Android AICore — experimental and only
 * on allowlisted devices (Pixel 8+/Galaxy S24-class) running API 31+. Everything is
 * guarded and wrapped in try/catch so on every other device (the large permanent
 * minority) the probe reports "unavailable" and generation returns null, and the
 * Dart router silently falls back to cloud — no user-visible downgrade.
 */
class MainActivity : FlutterActivity() {
    private val channelName = "momzo/on_device_ai"
    private val scope = CoroutineScope(Dispatchers.Main)

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "capability" -> result.success(capability())
                    "generate" -> generate(
                        call.argument<String>("prompt") ?: "",
                        call.argument<Int>("maxTokens") ?: 256,
                        result,
                    )
                    else -> result.notImplemented()
                }
            }
    }

    /**
     * Cheap, side-effect-free gate: API level + presence of AICore (Gemini Nano's
     * host). We deliberately do NOT pre-warm/download the model here — that would
     * risk a large silent download on a metered connection (strategy §3: treat
     * "downloading" as unavailable for now). The real readiness check happens lazily
     * in [generate], which falls back to cloud if the model isn't ready.
     */
    private fun capability(): String = try {
        val ok = Build.VERSION.SDK_INT >= 31 && isPackageInstalled("com.google.android.aicore")
        if (ok) "available" else "unavailable"
    } catch (e: Throwable) {
        "unknown"
    }

    /** Real on-device inference. Returns {text, confidence} or null (-> cloud fallback). */
    private fun generate(prompt: String, maxTokens: Int, result: MethodChannel.Result) {
        if (Build.VERSION.SDK_INT < 31 || prompt.isEmpty()) {
            result.success(null)
            return
        }
        scope.launch {
            val out: Map<String, Any?>? = try {
                val model = GenerativeModel(
                    generationConfig {
                        context = applicationContext
                        temperature = 0.6f
                        topK = 40
                        maxOutputTokens = maxTokens
                    },
                )
                try {
                    val response = withContext(Dispatchers.IO) { model.generateContent(prompt) }
                    val text = response.text
                    if (text.isNullOrEmpty()) null else mapOf("text" to text, "confidence" to null)
                } finally {
                    model.close()
                }
            } catch (e: Throwable) {
                // Feature absent / model not downloaded / device not allowlisted / inference
                // error — degrade to cloud rather than block or force a download.
                null
            }
            result.success(out)
        }
    }

    private fun isPackageInstalled(pkg: String): Boolean = try {
        packageManager.getPackageInfo(pkg, 0)
        true
    } catch (e: Throwable) {
        false
    }
}
