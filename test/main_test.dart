import 'package:bb_mobile/main.dart';
import 'package:bb_mobile/recoverbull_setup.dart';
import 'package:bull_payjoin/bull_payjoin.dart';
import 'package:bull_recoverbull/bull_recoverbull.dart';
import 'package:primitives/primitives.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockPayjoinLifecycle extends Mock implements PayjoinLifecycle {}

class _MockRecoverBullMonitoring extends Mock
    implements RecoverBullAttemptMonitoringController {}

void main() {
  test('resumes Payjoin recovery when the app returns to the foreground', () {
    final lifecycle = _MockPayjoinLifecycle();
    when(lifecycle.resume).thenAnswer((_) async => const Ok(null));

    resumePayjoinsOnAppResume(AppLifecycleState.paused, lifecycle);
    verifyNever(lifecycle.resume);

    resumePayjoinsOnAppResume(AppLifecycleState.resumed, lifecycle);
    verify(lifecycle.resume).called(1);
  });

  test('checks RecoverBull monitoring exactly once at app launch', () async {
    final monitoring = _MockRecoverBullMonitoring();
    when(monitoring.checkOnForeground).thenAnswer((_) async => const []);

    await checkRecoverBullOnAppLaunch(monitoring);
    verify(monitoring.checkOnForeground).called(1);
  });

  test('does not check RecoverBull monitoring when app resumes', () {
    final monitoring = _MockRecoverBullMonitoring();
    final lifecycle = _MockPayjoinLifecycle();
    when(lifecycle.resume).thenAnswer((_) async => const Ok(null));
    when(monitoring.checkOnForeground).thenAnswer((_) async => const []);

    resumePayjoinsOnAppResume(AppLifecycleState.resumed, lifecycle);
    verifyNever(monitoring.checkOnForeground);
  });
}
