import 'dart:convert';
import 'dart:io';

import 'package:integration_test/integration_test_driver.dart';

Future<void> main() async {
  final runId = Platform.environment['PERF_RUN_ID'] ??
      DateTime.now().millisecondsSinceEpoch.toString();
  final outDir = Platform.environment['PERF_OUT_DIR'] ?? 'testing/perf_exports';

  await integrationDriver(
    responseDataCallback: (Map<String, dynamic>? data) async {
      if (data == null) return;

      final directory = Directory(outDir);
      if (!directory.existsSync()) {
        directory.createSync(recursive: true);
      }

      final outputFile = File('${directory.path}/perf_run_$runId.json');
      final encoder = const JsonEncoder.withIndent('  ');
      outputFile.writeAsStringSync(encoder.convert(data));
      stdout.writeln('Saved perf export: ${outputFile.path}');
    },
  );
}
