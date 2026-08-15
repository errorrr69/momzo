import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../../core/theme/momzo_colors.dart';
import '../../../core/theme/momzo_text.dart';
import '../../../models/learning_game.dart';
import '../../../services/learning_game_service.dart';
import '../widgets/shelf_style.dart';

/// Hosts one learning game.
///
/// The game is the bundled SPA opened at its own route; Momzo supplies only the
/// chrome around it. Everything the game reports comes back through a single
/// JavaScript channel, `MomzoBridge` — one way, no PII, and nothing goes the
/// other way. The SPA has no network and no Supabase of its own (ADR 009).
class GamePlayerScreen extends StatefulWidget {
  final LearningGame game;
  const GamePlayerScreen({super.key, required this.game});

  @override
  State<GamePlayerScreen> createState() => _GamePlayerScreenState();
}

class _GamePlayerScreenState extends State<GamePlayerScreen> {
  late final WebViewController _controller;

  /// Raw bridge payloads, stored as sent so the dashboard can read more later.
  final List<Map<String, dynamic>> _events = [];
  final DateTime _openedAt = DateTime.now();

  String? _sessionId;
  bool _loading = true;
  bool _failed = false;
  bool _sawSummary = false;

  @override
  void initState() {
    super.initState();
    _open();
  }

  Future<void> _open() async {
    // Fire and forget: a session row is nice to have, never a reason to wait.
    LearningGameService.startSession(widget.game.slug).then((id) => _sessionId = id);

    // HashRouter inside the bundle (file:// has no History API), so the route
    // rides after the #. The games repo picks its router by protocol for exactly
    // this reason — see assets/games/README.md.
    final url = 'assets/games/index.html#${widget.game.entryPath}';

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(MomzoColors.cream)
      ..addJavaScriptChannel('MomzoBridge', onMessageReceived: _onBridgeMessage)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (_) {
            if (mounted) setState(() => _loading = false);
          },
          onWebResourceError: (e) {
            // Only the main document failing is fatal; a missing sub-resource
            // should not replace a playable game with an error screen.
            if (e.isForMainFrame ?? true) {
              if (mounted) setState(() => _failed = true);
            }
          },
          // Sealed subsystem: the bundle must not navigate anywhere off-device.
          onNavigationRequest: (r) => r.url.startsWith('http')
              ? NavigationDecision.prevent
              : NavigationDecision.navigate,
        ),
      );
    await _controller.loadFlutterAsset(url);
  }

  void _onBridgeMessage(JavaScriptMessage message) {
    try {
      final decoded = jsonDecode(message.message);
      if (decoded is! Map<String, dynamic>) return;
      _events.add(decoded);
      if (decoded['event'] == 'session_summary') _sawSummary = true;
    } catch (_) {
      // Malformed telemetry is discarded silently. The game keeps playing.
    }
  }

  @override
  void dispose() {
    final id = _sessionId;
    if (id != null) {
      LearningGameService.endSession(
        sessionId: id,
        durationSec: DateTime.now().difference(_openedAt).inSeconds,
        completed: _sawSummary,
        events: List<Map<String, dynamic>>.from(_events),
      );
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final style = ShelfStyle.of(widget.game.category);
    return Scaffold(
      backgroundColor: MomzoColors.cream,
      body: SafeArea(
        child: Column(
          children: [
            _header(style),
            Expanded(
              child: Stack(
                children: [
                  if (!_failed) WebViewWidget(controller: _controller),
                  if (_failed) _errorState(),
                  if (_loading && !_failed)
                    const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _header(ShelfStyle style) => Container(
        padding: const EdgeInsets.fromLTRB(8, 6, 16, 10),
        decoration: BoxDecoration(
          color: style.tint,
          border: const Border(bottom: BorderSide(color: MomzoColors.hairline)),
        ),
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back_rounded),
              color: style.text,
              // Closing is what ends the session, so it is also what sends the
              // summary. Nothing else needs to be "saved".
              onPressed: () => Navigator.pop(context),
              tooltip: 'Finish playing',
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.game.title,
                      style: MomzoText.sans(16, weight: FontWeight.w800, color: style.text)),
                  Text(style.shelf.label,
                      style: MomzoText.sans(12, weight: FontWeight.w700, color: MomzoColors.muted)),
                ],
              ),
            ),
          ],
        ),
      );

  Widget _errorState() => Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('This one won’t open just now',
                  textAlign: TextAlign.center,
                  style: MomzoText.serif(22, color: MomzoColors.ink)),
              const SizedBox(height: 10),
              Text(
                'Nothing’s broken on your side — try another game, or come back to '
                'this one in a bit.',
                textAlign: TextAlign.center,
                style: MomzoText.sans(15, color: MomzoColors.body),
              ),
            ],
          ),
        ),
      );
}
