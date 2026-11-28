import 'dart:async';

import 'package:bb_mobile/app.dart';
import 'package:startup/startup.dart';
import 'package:bull_payjoin/bull_payjoin.dart';
import 'package:primitives/primitives.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sync/sync.dart';

class _MockPayjoinLifecycle extends Mock implements PayjoinLifecycle {}

void main() {
  test('foreground recovery waits for wallet runtime startup', () async {
    final lifecycle = _MockPayjoinLifecycle();
    when(lifecycle.resume).thenAnswer((_) async => const Ok(null));
    final initialized = Completer<Result<void, SyncFailure>>();
    var starts = 0;
    final startup = ForegroundWalletStartup(
      initialize: () => initialized.future,
      startWatchers: () => starts++,
      payjoin: () => lifecycle,
    );

    resumePayjoinsOnAppResume(AppLifecycleState.resumed, startup);
    verifyNever(lifecycle.resume);
    final starting = startup.start();
    expect(startup.start(), same(starting));
    resumePayjoinsOnAppResume(AppLifecycleState.resumed, startup);
    expect(starts, 0);
    verifyNever(lifecycle.resume);
    initialized.complete(const Ok(null));
    await starting;
    expect(starts, 1);
    verify(lifecycle.resume).called(1);

    resumePayjoinsOnAppResume(AppLifecycleState.paused, startup);
    verifyNever(lifecycle.resume);

    resumePayjoinsOnAppResume(AppLifecycleState.resumed, startup);
    verify(lifecycle.resume).called(1);
    await startup.start();
    expect(starts, 1);
    verifyNever(lifecycle.resume);
  });
}
