import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:makeup/main.dart' as app;

Future<void> _pumpQuietly(WidgetTester tester, {Duration duration = const Duration(milliseconds: 500)}) async {
  await tester.pump(duration);
  await tester.pumpAndSettle(const Duration(milliseconds: 250));
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

  await tester.fling(scrollable.first, const Offset(0, -500), 1200);
  await _pumpQuietly(tester, duration: const Duration(milliseconds: 800));
  await tester.fling(scrollable.first, const Offset(0, 500), 1200);
  await _pumpQuietly(tester, duration: const Duration(milliseconds: 800));
}

Future<void> _runScenario(WidgetTester tester) async {
  // Keep this sequence deterministic across runs.
  await _tapTextIfPresent(tester, 'Weekly');
  await _tapTextIfPresent(tester, 'League');
  await _tapTextIfPresent(tester, 'Profile');
  await _tapTextIfPresent(tester, 'Daily');

  await _scrollFirstScrollable(tester);

  // Optional common interactions if present in the current state.
  await _tapTextIfPresent(tester, 'Begin 4-Week League');
  await _tapTextIfPresent(tester, 'Begin League');
  await _tapTextIfPresent(tester, 'Close');

  // Give final frame activity time to settle.
  await _pumpQuietly(tester, duration: const Duration(seconds: 1));
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

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
