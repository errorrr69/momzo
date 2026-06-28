package app.momzo

import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Native bridge for the on-device AI layer (On-Device AI Strategy §3/§4).
 *
 * Phase 2a: a real, conservative capability probe. There is no "connect your AI"
 * flow — we just ask the OS whether an on-device GenAI runtime (Android AICore /
 * Gemini Nano) is present. On devices without it (the large permanent minority),
 * this returns "unavailable" and the app silently uses cloud — no user-visible
 * downgrade. Actual on-device generation is wired in a later step behind the same
 * channel; until then `generate` reports unavailable so the router falls back.
 */
class MainActivity : FlutterActivity() {
    private val channelName = "momzo/on_device_ai"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "capability" -> result.success(capability())
                    "generate" -> result.success(null) // not yet implemented -> router falls back to cloud
                    else -> result.notImplemented()
                }
            }
    }

    /** "available" | "unavailable" | "unknown" — conservative; false-negatives just mean cloud. */
    private fun capability(): String {
        return try {
            // AICore is the system component that hosts Gemini Nano. Its presence on a
            // recent Android is our gate; we stay conservative and treat anything else as
            // unavailable (cloud). The real SDK feature-status check refines this once the
            // generate path is added.
            val hasAiCore = isPackageInstalled("com.google.android.aicore")
            if (hasAiCore && Build.VERSION.SDK_INT >= 34) "available" else "unavailable"
        } catch (e: Exception) {
            "unknown"
        }
    }

    private fun isPackageInstalled(pkg: String): Boolean = try {
        packageManager.getPackageInfo(pkg, 0)
        true
    } catch (e: Exception) {
        false
    }
}
