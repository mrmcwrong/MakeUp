import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:makeup/main.dart' as app;

const _targetFrameStep = Duration(milliseconds: 11);

Future<void> _pumpQuietly(WidgetTester tester) async {
  // Keep progress aligned with a 90 Hz cadence (~11.11 ms) so the harness
  // doesn't bias results toward 60 fps-like frame pacing.
  await tester.pump(_targetFrameStep);
  await tester.pumpAndSettle(_targetFrameStep);
}

Future<void> _tapTextIfPresent(WidgetTester tester, String text) async {
  final finder = find.text(text);
  if (finder.evaluate().isNotEmpty) {
    await tester.tap(finder.first);
    await _pumpQuietly(tester);
  }
}

Future<void> _scrollFirstScrollable(WidgetTester tester) async {
  final scrollable = find.byType(Scrollable);
  if (scrollable.evaluate().isEmpty) return;

  await tester.timedDrag(
    scrollable.first,
    const Offset(0, -500),
    const Duration(milliseconds: 420),
    frequency: 90,
  );
  await _pumpQuietly(tester);
  await tester.timedDrag(
    scrollable.first,
    const Offset(0, 500),
    const Duration(milliseconds: 420),
    frequency: 90,
  );
  await _pumpQuietly(tester);
}

Future<void> _runScenario(WidgetTester tester) async {
  // Keep this sequence deterministic across runs.
  await _tapTextIfPresent(tester, 'Weekly');
  await _tapTextIfPresent(tester, 'League');
  await _tapTextIfPresent(tester, 'Profile');
  await _tapTextIfPresent(tester, 'Daily');

  await _scrollFirstScrollable(tester);

  // Give final frame activity time to settle.
  await _pumpQuietly(tester);
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;

  testWidgets('Automated performance journey with timeline capture', (
    WidgetTester tester,
  ) async {
    const runLabel = String.fromEnvironment('PERF_RUN_ID', defaultValue: 'manual');

    app.main();
    await tester.pumpAndSettle(const Duration(seconds: 3));

    await binding.traceAction(() async {
      await _runScenario(tester);
    }, reportKey: 'perf_timeline');

    final existing = binding.reportData ?? <String, dynamic>{};
    binding.reportData = <String, dynamic>{
      ...existing,
      'runLabel': runLabel,
      'capturedAt': DateTime.now().toIso8601String(),
      'scenario': 'daily-weekly-league-profile-daily-scroll',
    };
  });
}
