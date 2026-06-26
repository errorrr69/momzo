import 'package:flutter_tts/flutter_tts.dart';

/// On-device text-to-speech for the bonding games' "tap to hear" button. Uses the
/// free, offline system voice (no AI / no per-use cost — games spec §1.2). All
/// calls are best-effort and never throw.
class TtsService {
  const TtsService._();
  static final FlutterTts _tts = FlutterTts();

  static Future<void> speak(String text) async {
    try {
      await _tts.stop();
      await _tts.setSpeechRate(0.45); // gentle, child-friendly pace
      await _tts.setPitch(1.05);
      await _tts.speak(text);
    } catch (_) {/* speech is optional */}
  }

  static Future<void> stop() async {
    try {
      await _tts.stop();
    } catch (_) {}
  }
}
