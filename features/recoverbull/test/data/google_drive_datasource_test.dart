import 'package:bull_recoverbull/src/data/datasources/google_drive_datasource.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:mocktail/mocktail.dart';

import '../support/log_sink.dart';

class _GoogleSignIn extends Mock implements GoogleSignIn {}

void main() {
  test('a failed silent sign-in keeps the user\'s Drive grant', () async {
    final google = _GoogleSignIn();
    when(google.signInSilently).thenThrow(Exception('transient'));
    when(google.disconnect).thenAnswer((_) async => null);
    when(google.signOut).thenAnswer((_) async => null);
    final datasource = GoogleDriveAppDatasource(
      log: const TestLogSink(),
      googleSignIn: google,
    );

    expect(await datasource.connectSilently(), isNull);

    verifyNever(google.disconnect);
    verifyNever(google.signOut);
    await expectLater(
      datasource.fetchFileContent('file'),
      throwsA(isA<Exception>()),
    );
  });

  test('a failed interactive sign-in keeps the user\'s Drive grant', () async {
    final google = _GoogleSignIn();
    when(google.signIn).thenThrow(Exception('transient'));
    when(google.disconnect).thenAnswer((_) async => null);
    when(google.signOut).thenAnswer((_) async => null);
    final datasource = GoogleDriveAppDatasource(
      log: const TestLogSink(),
      googleSignIn: google,
    );

    await expectLater(datasource.connect(), throwsA(isA<Exception>()));

    verifyNever(google.disconnect);
    verifyNever(google.signOut);
    await expectLater(
      datasource.fetchFileContent('file'),
      throwsA(isA<Exception>()),
    );
  });

  test('silent sign-in propagates programmer errors', () async {
    final google = _GoogleSignIn();
    when(google.signInSilently).thenThrow(StateError('programmer bug'));
    final datasource = GoogleDriveAppDatasource(
      log: const TestLogSink(),
      googleSignIn: google,
    );
    await expectLater(datasource.connectSilently(), throwsStateError);
    verifyNever(google.disconnect);
    verifyNever(google.signOut);
  });
}
