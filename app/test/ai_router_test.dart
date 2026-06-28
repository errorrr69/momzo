// Unit tests for the AI routing table (On-Device AI Strategy §9 Phase-1 acceptance):
//  - the (risk × capability) table is pure and correct,
//  - the pre-screen forces cloud on a sensitive-question battery,
//  - swapping in a stub provider needs no app changes.
// Pure logic only — no Supabase, no fonts, no network.
import 'package:flutter_test/flutter_test.dart';

import 'package:momzo/core/ai/ai_prescreen.dart';
import 'package:momzo/core/ai/ai_provider.dart';
import 'package:momzo/core/ai/ai_request.dart';
import 'package:momzo/core/ai/ai_router.dart';
import 'package:momzo/core/ai/ai_telemetry.dart';
import 'package:momzo/core/ai/on_device_capability.dart';
import 'package:momzo/core/ai/on_device_provider.dart';

/// Records which provider was asked to generate.
class _StubProvider implements AiProvider {
  final String label;
  final List<AiRequest> seen = [];
  _StubProvider(this.label);
  @override
  Future<bool> isAvailable() async => true;
  @override
  Future<AiResult> generate(AiRequest req) async {
    seen.add(req);
    return AiResult(text: label, source: label);
  }
}

/// A fake on-device engine for testing the provider + router guards without Nano.
class _FakeEngine implements OnDeviceEngine {
  final OnDeviceResponse? Function(String prompt) onRun;
  _FakeEngine(this.onRun);
  @override
  Future<OnDeviceResponse?> run(String prompt, {int maxTokens = 256}) async => onRun(prompt);
}

OnDeviceProvider _onDeviceWith(OnDeviceResponse? Function(String) onRun) => OnDeviceProvider(
      engine: _FakeEngine(onRun),
      isAvailable: () async => true,
    );

void main() {
  group('chooseBrain table', () {
    test('red is always cloud, regardless of capability', () {
      for (final cap in OnDeviceCapability.values) {
        expect(AiRouter.chooseBrain(AiRiskClass.red, cap), AiBrain.cloud);
      }
    });

    test('non-available capability is always cloud', () {
      for (final risk in AiRiskClass.values) {
        expect(AiRouter.chooseBrain(risk, OnDeviceCapability.unavailable), AiBrain.cloud);
        expect(AiRouter.chooseBrain(risk, OnDeviceCapability.unknown), AiBrain.cloud);
      }
    });

    test('green + amber go on-device only when available', () {
      expect(AiRouter.chooseBrain(AiRiskClass.green, OnDeviceCapability.available), AiBrain.onDevice);
      expect(AiRouter.chooseBrain(AiRiskClass.amber, OnDeviceCapability.available), AiBrain.onDevice);
    });
  });

  group('pre-screen risk tagging', () {
    test('game top-up is green', () {
      expect(AiPrescreen.riskFor(const AiRequest(task: AiTask.gameItem, risk: AiRiskClass.green)),
          AiRiskClass.green);
    });

    test('ordinary expert / situational questions are amber', () {
      expect(
          AiPrescreen.riskFor(const AiRequest(
              task: AiTask.expertQa, risk: AiRiskClass.amber, prompt: 'how do I handle bedtime?')),
          AiRiskClass.amber);
      expect(
          AiPrescreen.riskFor(const AiRequest(
              task: AiTask.situational, risk: AiRiskClass.amber, prompt: 'he wont put his shoes on')),
          AiRiskClass.amber);
    });

    test('sensitive-question battery is elevated to red', () {
      const battery = [
        'I think my child wants to hurt himself',
        'could this be autism or adhd?',
        'she has a high fever and a rash',
        'I am so depressed I cannot cope',
        'is someone abusing my child',
      ];
      for (final q in battery) {
        expect(
          AiPrescreen.riskFor(AiRequest(task: AiTask.expertQa, risk: AiRiskClass.amber, prompt: q)),
          AiRiskClass.red,
          reason: 'should flag: "$q"',
        );
      }
    });
  });

  group('AiRouter.generate routes to the chosen provider', () {
    setUp(() => OnDeviceProbe.debugSetCapability(null));
    tearDown(() => OnDeviceProbe.debugSetCapability(null));

    test('green task on a capable device goes to the on-device provider', () async {
      OnDeviceProbe.debugSetCapability(OnDeviceCapability.available);
      final cloud = _StubProvider('cloud');
      final onDevice = _StubProvider('on_device');
      final router = AiRouter(cloud: cloud, onDevice: onDevice);

      final r = await router.generate(
          const AiRequest(task: AiTask.gameItem, risk: AiRiskClass.green, gameSlug: 'hot-seat'));

      expect(r.source, 'on_device');
      expect(onDevice.seen, hasLength(1));
      expect(cloud.seen, isEmpty);
    });

    test('a sensitive expert question always lands on cloud, even when capable', () async {
      OnDeviceProbe.debugSetCapability(OnDeviceCapability.available);
      final cloud = _StubProvider('cloud');
      final onDevice = _StubProvider('on_device');
      final router = AiRouter(cloud: cloud, onDevice: onDevice);

      final r = await router.generate(const AiRequest(
          task: AiTask.expertQa, risk: AiRiskClass.amber, prompt: 'I want to hurt myself'));

      expect(r.source, 'cloud');
      expect(cloud.seen.single.risk, AiRiskClass.red); // pre-screen elevated it
      expect(onDevice.seen, isEmpty);
    });

    test('default capability (no override) resolves to cloud', () async {
      // No platform handler -> probe degrades to unavailable -> cloud.
      final cloud = _StubProvider('cloud');
      final router = AiRouter(cloud: cloud);
      final r = await router.generate(
          const AiRequest(task: AiTask.gameItem, risk: AiRiskClass.green, gameSlug: 'charades'));
      expect(r.source, 'cloud');
    });
  });

  group('on-device guards + cloud fallback (strategy §4.3/§5/§6)', () {
    setUp(() => OnDeviceProbe.debugSetCapability(OnDeviceCapability.available));
    tearDown(() => OnDeviceProbe.debugSetCapability(null));

    test('green answers on-device when the engine returns text', () async {
      final cloud = _StubProvider('cloud');
      final router = AiRouter(
        cloud: cloud,
        onDevice: _onDeviceWith((_) => const OnDeviceResponse('{"items":[]}')),
      );
      final r = await router.generate(
          const AiRequest(task: AiTask.gameItem, risk: AiRiskClass.green, gameSlug: 'hot-seat'));
      expect(r.source, 'on_device');
      expect(cloud.seen, isEmpty);
    });

    test('on-device unavailable (engine null) falls back to cloud', () async {
      final cloud = _StubProvider('cloud');
      final router = AiRouter(
        cloud: cloud,
        onDevice: _onDeviceWith((_) => null), // engine declines
      );
      final r = await router.generate(
          const AiRequest(task: AiTask.gameItem, risk: AiRiskClass.green, gameSlug: 'hot-seat'));
      expect(r.source, 'cloud');
      expect(cloud.seen, hasLength(1));
    });

    test('amber with low/absent confidence falls back to cloud', () async {
      final cloud = _StubProvider('cloud');
      final router = AiRouter(
        cloud: cloud,
        amberConfidenceFloor: 0.6,
        onDevice: _onDeviceWith((_) => const OnDeviceResponse('a calm script', confidence: 0.3)),
      );
      final r = await router.generate(const AiRequest(
          task: AiTask.situational, risk: AiRiskClass.amber, prompt: 'he wont nap'));
      expect(r.source, 'cloud');
    });

    test('amber with high confidence is served on-device', () async {
      final cloud = _StubProvider('cloud');
      final router = AiRouter(
        cloud: cloud,
        amberConfidenceFloor: 0.6,
        onDevice: _onDeviceWith((_) => const OnDeviceResponse('a calm script', confidence: 0.9)),
      );
      final r = await router.generate(const AiRequest(
          task: AiTask.situational, risk: AiRiskClass.amber, prompt: 'he wont nap'));
      expect(r.source, 'on_device');
    });

    test('on-device output that trips the safety screen is discarded for cloud', () async {
      final cloud = _StubProvider('cloud');
      final router = AiRouter(
        cloud: cloud,
        amberConfidenceFloor: 0.6,
        // High confidence, but the answer touches a sensitive marker -> must not show.
        onDevice: _onDeviceWith(
            (_) => const OnDeviceResponse('you should give him medication', confidence: 0.95)),
      );
      final r = await router.generate(const AiRequest(
          task: AiTask.situational, risk: AiRiskClass.amber, prompt: 'he keeps coughing'));
      expect(r.source, 'cloud');
    });
  });

  group('telemetry (strategy §7)', () {
    final events = <AiTelemetryEvent>[];
    setUp(() {
      events.clear();
      AiTelemetry.setSink(events.add);
      OnDeviceProbe.debugSetCapability(OnDeviceCapability.available);
    });
    tearDown(() {
      AiTelemetry.setSink(null);
      OnDeviceProbe.debugSetCapability(null);
    });

    test('records source + fellBack=false when on-device serves', () async {
      final router = AiRouter(
        cloud: _StubProvider('cloud'),
        onDevice: _onDeviceWith((_) => const OnDeviceResponse('{"items":[]}')),
      );
      await router.generate(
          const AiRequest(task: AiTask.gameItem, risk: AiRiskClass.green, gameSlug: 'hot-seat'));
      expect(events, hasLength(1));
      expect(events.single.source, 'on_device');
      expect(events.single.fellBack, isFalse);
      expect(events.single.task, AiTask.gameItem);
    });

    test('records fellBack=true when on-device declines and cloud serves', () async {
      final router = AiRouter(
        cloud: _StubProvider('cloud'),
        onDevice: _onDeviceWith((_) => null),
      );
      await router.generate(
          const AiRequest(task: AiTask.gameItem, risk: AiRiskClass.green, gameSlug: 'hot-seat'));
      expect(events.single.source, 'cloud');
      expect(events.single.fellBack, isTrue);
    });
  });
}
