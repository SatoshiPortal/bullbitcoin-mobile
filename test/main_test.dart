import 'package:bb_mobile/main.dart';
import 'package:bull_payjoin/bull_payjoin.dart';
import 'package:primitives/primitives.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockPayjoinLifecycle extends Mock implements PayjoinLifecycle {}

void main() {
  test('resumes Payjoin recovery when the app returns to the foreground', () {
    final lifecycle = _MockPayjoinLifecycle();
    when(lifecycle.resume).thenAnswer((_) async => const Ok(null));

    resumePayjoinsOnAppResume(AppLifecycleState.paused, lifecycle);
    verifyNever(lifecycle.resume);

    resumePayjoinsOnAppResume(AppLifecycleState.resumed, lifecycle);
    verify(lifecycle.resume).called(1);
  });
}
