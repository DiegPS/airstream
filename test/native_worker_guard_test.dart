import 'dart:async';

import 'package:airstream/services/native_worker_guard.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('reports an isolate error that happens after the worker is ready',
      () async {
    final reported = Completer<(Object, bool)>();
    final guard = NativeWorkerGuard(
      label: 'test worker',
      onFailure: (error, failedAfterReady) {
        reported.complete((error, failedAfterReady));
      },
    );
    guard.markReady();

    guard.errorPort.sendPort.send(['native failure', 'stack']);
    final failure = await reported.future.timeout(const Duration(seconds: 1));

    expect(failure.$1.toString(), contains('native failure'));
    expect(failure.$2, isTrue);
    await guard.dispose(expectedExit: false);
  });

  test('reports an unexpected clean isolate exit', () async {
    final reported = Completer<Object>();
    final guard = NativeWorkerGuard(
      label: 'test worker',
      onFailure: (error, _) => reported.complete(error),
    );
    guard.markReady();

    guard.exitPort.sendPort.send(null);
    final failure = await reported.future.timeout(const Duration(seconds: 1));

    expect(failure.toString(), contains('exited unexpectedly'));
    await guard.dispose(expectedExit: false);
  });
}
