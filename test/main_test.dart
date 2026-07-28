import 'package:bb_mobile/core/payjoin/domain/repositories/payjoin_repository.dart';
import 'package:bb_mobile/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockPayjoinRepository extends Mock implements PayjoinRepository {}

void main() {
  test('resumes Payjoin recovery when the app returns to the foreground', () {
    final repository = _MockPayjoinRepository();
    when(repository.resumePayjoinsOnStartup).thenAnswer((_) async {});

    resumePayjoinsOnAppResume(AppLifecycleState.paused, repository);
    verifyNever(repository.resumePayjoinsOnStartup);

    resumePayjoinsOnAppResume(AppLifecycleState.resumed, repository);
    verify(repository.resumePayjoinsOnStartup).called(1);
  });
}
