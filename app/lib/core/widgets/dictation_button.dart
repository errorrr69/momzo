import 'package:flutter/material.dart';
import '../../services/stt_service.dart';
import '../theme/momzo_colors.dart';

/// A tap-to-dictate mic button for text composers (Task 35 — voice input for AI).
///
/// Streams free, on-device speech-to-text into [controller] for hands-full
/// moments. Best-effort: if the device has no recognizer or denies the mic, the
/// button hides itself and the parent keeps working as a normal typing field.
/// Transcribed text flows through the same composer + send path, so the server's
/// RAG grounding and refer-out safety pipeline apply unchanged (Hard Rule #7).
class DictationButton extends StatefulWidget {
  final TextEditingController controller;
  final bool enabled;
  final double size;
  const DictationButton({
    super.key,
    required this.controller,
    this.enabled = true,
    this.size = 44,
  });

  @override
  State<DictationButton> createState() => _DictationButtonState();
}

class _DictationButtonState extends State<DictationButton> {
  bool _ready = false;
  bool _listening = false;
  String _base = ''; // composer text captured when dictation starts

  @override
  void initState() {
    super.initState();
    SttService.ensureReady().then((ok) {
      if (mounted) setState(() => _ready = ok);
    });
  }

  @override
  void dispose() {
    if (_listening) SttService.stop();
    super.dispose();
  }

  Future<void> _toggle() async {
    if (!_ready) return;
    if (_listening || SttService.isListening) {
      await SttService.stop();
      if (mounted) setState(() => _listening = false);
      return;
    }
    _base = widget.controller.text.trimRight();
    setState(() => _listening = true);
    await SttService.listen(onResult: (text, isFinal) {
      if (!mounted) return;
      final merged = _base.isEmpty ? text : '$_base $text';
      widget.controller
        ..text = merged
        ..selection = TextSelection.collapsed(offset: merged.length);
      if (isFinal) setState(() => _listening = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    // Silently absent on devices without dictation — the field still works.
    if (!_ready) return const SizedBox.shrink();
    final active = _listening;
    return GestureDetector(
      onTap: widget.enabled ? _toggle : null,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: widget.size,
        height: widget.size,
        margin: const EdgeInsets.only(right: 4),
        decoration: BoxDecoration(
          color: active ? MomzoColors.coral : MomzoColors.coralTint,
          shape: BoxShape.circle,
        ),
        child: Icon(
          active ? Icons.stop_rounded : Icons.mic_rounded,
          color: active ? Colors.white : MomzoColors.coral,
          size: 20,
        ),
      ),
    );
  }
}
