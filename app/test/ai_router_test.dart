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
import 'package:momzo/core/ai/on_device_capability.dart';

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

    test('default (Phase 1) capability resolves to cloud', () async {
      // No override -> the real probe stub returns unavailable.
      final cloud = _StubProvider('cloud');
      final router = AiRouter(cloud: cloud);
      final r = await router.generate(
          const AiRequest(task: AiTask.gameItem, risk: AiRiskClass.green, gameSlug: 'charades'));
      expect(r.source, 'cloud');
    });
  });
}
