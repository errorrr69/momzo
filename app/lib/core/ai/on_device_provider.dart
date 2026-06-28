import 'package:flutter/services.dart';

import 'ai_provider.dart';
import 'ai_request.dart';

/// One on-device inference. `confidence` is exposed when the OS model provides it
/// (used for amber gating, strategy §6); null means "no signal".
class OnDeviceResponse {
  final String text;
  final double? confidence;
  const OnDeviceResponse(this.text, {this.confidence});
}

/// The thing that actually runs a prompt on the device's OS model. Abstracted so
/// the provider's routing/safety logic is testable with a fake (no Nano hardware).
abstract class OnDeviceEngine {
  /// Returns null when the device can't serve this right now (no model / busy /
  /// unsupported) — the router then falls back to cloud.
  Future<OnDeviceResponse?> run(String prompt, {int maxTokens});
}

/// Real engine: calls the native bridge (Android AICore / Gemini Nano; iOS
/// Foundation Models). Returns null on any platform error so we fall back to cloud.
class PlatformOnDeviceEngine implements OnDeviceEngine {
  const PlatformOnDeviceEngine();
  static const _channel = MethodChannel('momzo/on_device_ai');

  @override
  Future<OnDeviceResponse?> run(String prompt, {int maxTokens = 256}) async {
    try {
      final res = await _channel.invokeMapMethod<String, dynamic>(
        'generate',
        {'prompt': prompt, 'maxTokens': maxTokens},
      );
      final text = res?['text'] as String?;
      if (text == null || text.isEmpty) return null;
      final c = res?['confidence'];
      return OnDeviceResponse(text, confidence: c is num ? c.toDouble() : null);
    } on MissingPluginException {
      return null;
    } catch (_) {
      return null;
    }
  }
}

/// Thrown when the on-device path can't produce a usable answer — the router
/// catches it and falls back to cloud (strategy §4.3 step 5b).
class OnDeviceUnavailable implements Exception {
  final String reason;
  const OnDeviceUnavailable(this.reason);
  @override
  String toString() => 'OnDeviceUnavailable($reason)';
}

/// The on-device brain (strategy §4.2). Builds a task prompt, runs it through the
/// OS model, and returns an [AiResult] tagged `on_device`. It never makes the final
/// safety call itself — the router runs the post-answer screen and falls back to
/// cloud when anything is off (strategy §5).
class OnDeviceProvider implements AiProvider {
  final OnDeviceEngine engine;
  final Future<bool> Function() _available;

  OnDeviceProvider({required this.engine, required Future<bool> Function() isAvailable})
      : _available = isAvailable;

  @override
  Future<bool> isAvailable() => _available();

  @override
  Future<AiResult> generate(AiRequest req) async {
    final resp = await engine.run(_buildPrompt(req), maxTokens: req.maxTokens);
    if (resp == null) throw const OnDeviceUnavailable('engine returned null');
    return AiResult(
      text: resp.text.trim(),
      source: 'on_device',
      confidence: resp.confidence,
    );
  }

  String _buildPrompt(AiRequest req) {
    switch (req.task) {
      case AiTask.gameItem:
        final band = req.childAgeBand ?? 'B';
        final excl = req.excludeItems.take(30).join(' | ');
        return 'Generate fun, child-safe content for the "${req.gameSlug}" game '
            '(age band $band). Avoid: $excl';
      case AiTask.situational:
      case AiTask.expertQa:
      default:
        final ctx = req.contextChunks.isEmpty ? '' : '\n\nUse these notes:\n${req.contextChunks.join('\n')}';
        return '${req.prompt}$ctx';
    }
  }
}
