// Exercises the REAL on-device generation path (not the fake engine): the actual
// PlatformOnDeviceEngine talking over the 'momzo/on_device_ai' MethodChannel, with
// only the OS-model call itself mocked (the irreducible piece that needs Nano
// silicon). Verifies the Dart↔native contract — request marshalling and response
// parsing — and the full pipeline through OnDeviceProvider + AiRouter.
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:momzo/core/ai/ai_provider.dart';
import 'package:momzo/core/ai/ai_request.dart';
import 'package:momzo/core/ai/ai_router.dart';
import 'package:momzo/core/ai/on_device_capability.dart';
import 'package:momzo/core/ai/on_device_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('momzo/on_device_ai');
  final calls = <MethodCall>[];

  void mock(Object? Function(MethodCall call) handler) {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return handler(call);
    });
  }

  setUp(() {
    calls.clear();
    OnDeviceProbe.reset();
    OnDeviceProbe.debugSetCapability(OnDeviceCapability.available);
  });
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
    OnDeviceProbe.debugSetCapability(null);
  });

  test('PlatformOnDeviceEngine marshals the request + parses the model response', () async {
    mock((call) {
      if (call.method == 'generate') {
        return {'text': 'a gentle calm script', 'confidence': 0.91};
      }
      return null;
    });

    const engine = PlatformOnDeviceEngine();
    final resp = await engine.run('he wont nap', maxTokens: 128);

    // Parsed the native payload...
    expect(resp, isNotNull);
    expect(resp!.text, 'a gentle calm script');
    expect(resp.confidence, 0.91);
    // ...and sent the right request across the channel.
    expect(calls.single.method, 'generate');
    final args = calls.single.arguments as Map;
    expect(args['prompt'], 'he wont nap');
    expect(args['maxTokens'], 128);
  });

  test('native returning null (no model) -> engine null -> router cloud fallback', () async {
    mock((call) => null); // device has no on-device model
    final cloud = _Cloud();
    final router = AiRouter(
      cloud: cloud,
      onDevice: OnDeviceProvider(
        engine: const PlatformOnDeviceEngine(),
        isAvailable: () async => true,
      ),
    );
    final r = await router.generate(const AiRequest(
        task: AiTask.situational, risk: AiRiskClass.amber, prompt: 'he wont nap'));
    expect(r.source, 'cloud'); // graceful fallback, no crash
  });

  test('end-to-end generation: real engine + mocked model -> safety-filtered items on-device',
      () async {
    // The "OS model" returns two items; one is unsafe and must be dropped.
    mock((call) {
      if (call.method == 'generate') {
        return {
          'text': '{"items":[{"question":"cats or dogs?"},{"q":"who would win in a war"}]}',
          'confidence': null,
        };
      }
      return null;
    });
    final cloud = _Cloud();
    final router = AiRouter(
      cloud: cloud,
      onDevice: OnDeviceProvider(
        engine: const PlatformOnDeviceEngine(),
        isAvailable: () async => true,
      ),
    );
    final r = await router.generate(
        const AiRequest(task: AiTask.gameItem, risk: AiRiskClass.green, gameSlug: 'hot-seat'));

    expect(r.source, 'on_device'); // the real engine produced it
    expect(r.items, hasLength(1)); // the "war" item was filtered out
    expect(r.items!.single['question'], 'cats or dogs?');
  });
}

// Minimal cloud stub.
class _Cloud implements AiProvider {
  @override
  Future<bool> isAvailable() async => true;
  @override
  Future<AiResult> generate(AiRequest req) async => const AiResult(text: 'cloud', source: 'cloud');
}
