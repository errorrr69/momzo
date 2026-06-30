import 'package:speech_to_text/speech_to_text.dart';

/// Free, on-device speech-to-text (OS-provided; no paid cloud service) for Two
/// Truths & a Lie. All calls are best-effort: if the device has no recognizer or
/// denies the mic, [ensureReady] returns false and the UI falls back to typing.
class SttService {
  const SttService._();

  static final SpeechToText _stt = SpeechToText();
  static bool _tried = false;
  static bool _available = false;

  /// Initialise once; returns whether dictation can be used on this device.
  static Future<bool> ensureReady() async {
    if (_tried) return _available;
    _tried = true;
    try {
      _available = await _stt.initialize(onError: (_) {}, onStatus: (_) {});
    } catch (_) {
      _available = false;
    }
    return _available;
  }

  static bool get isListening => _stt.isListening;

  /// Stream partial + final transcripts to [onResult]; auto-stops on a pause.
  static Future<void> listen({required void Function(String text, bool isFinal) onResult}) async {
    if (!_available) return;
    await _stt.listen(
      onResult: (r) => onResult(r.recognizedWords, r.finalResult),
      listenFor: const Duration(seconds: 30),
      pauseFor: const Duration(seconds: 4),
      listenOptions: SpeechListenOptions(partialResults: true, cancelOnError: true),
    );
  }

  static Future<void> stop() async {
    try {
      await _stt.stop();
    } catch (_) {}
  }
}
