import 'dart:convert';
import 'dart:developer' as developer;

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
  bool _routed = false;

  @override
  void initState() {
    super.initState();
    _open();
  }

  Future<void> _open() async {
    // Fire and forget: a session row is nice to have, never a reason to wait.
    LearningGameService.startSession(widget.game.slug).then((id) => _sessionId = id);

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(MomzoColors.cream)
      // Without this a JS failure is completely invisible: the page "loads",
      // every callback reports success, and the screen is simply blank. That is
      // exactly how the ES-module-over-file:// problem presented, and it cost a
      // build cycle to find. Surfaced under the 'games.webview' log name.
      ..setOnConsoleMessage((msg) {
        developer.log('[${msg.level.name}] ${msg.message}', name: 'games.webview');
      })
      ..addJavaScriptChannel('MomzoBridge', onMessageReceived: _onBridgeMessage)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (_) async {
            // The route is applied AFTER load, not baked into the URL.
            //
            // loadFlutterAsset takes an asset KEY, not a URL — passing
            // 'index.html#/play/x' makes it hunt for an asset of that literal
            // name, find nothing, and hang with no error and no page-finished.
            // So: load the document, then move the hash. HashRouter picks that
            // up as navigation without a reload, and the spinner stays up until
            // it has, so the home route never flashes past.
            if (!_routed) {
              _routed = true;
              try {
                await _controller.runJavaScript(
                  "window.location.hash = '${widget.game.entryPath}';",
                );
              } catch (_) {
                // Fall through: the game is on screen, just on the wrong route.
              }
            }
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

    try {
      await _controller.loadFlutterAsset('assets/games/index.html');
    } catch (_) {
      if (mounted) setState(() => _failed = true);
      return;
    }

    // Everything here is on-device, so a load that has not finished in a few
    // seconds is not slow — it is stuck. Say so rather than spinning forever,
    // which is precisely how the asset-key bug presented: no error, no page,
    // no end.
    Future.delayed(const Duration(seconds: 8), () {
      if (mounted && _loading) setState(() => _failed = true);
    });
  }

  void _onBridgeMessage(JavaScriptMessage message) {
    try {
      final decoded = jsonDecode(message.message);
      if (decoded is! Map<String, dynamic>) return;

      // The game re-sends its rollup after every answer, so that closing the
      // WebView — which kills the page without unmounting it — can never lose
      // the session. Only the newest one is worth keeping; the earlier ones are
      // strictly prefixes of it.
      if (decoded['event'] == 'session_summary') {
        _events.removeWhere((e) => e['event'] == 'session_summary');
      }
      _events.add(decoded);
      // Logged under the same name as the WebView console, because a bridge that
      // delivers nothing looks exactly like a game nobody played. It shipped
      // broken once for that reason: the SPA detached postMessage from its
      // channel, Android rejected every unbound call, and the games app's own
      // catch swallowed it. Sessions recorded, `events` stayed empty, and no
      // log anywhere said otherwise.
      developer.log('bridge: ${decoded['event']}', name: 'games.webview');
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
