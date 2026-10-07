import 'package:bull_recoverbull/src/data/datasources/google_drive_datasource.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:mocktail/mocktail.dart';

import '../support/log_sink.dart';

class _GoogleSignIn extends Mock implements GoogleSignIn {}

void main() {
  test('a failed silent sign-in keeps the user\'s Drive grant', () async {
    final google = _GoogleSignIn();
    when(google.signInSilently).thenThrow(StateError('transient'));
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
      throwsA('unauthenticated'),
    );
  });

  test('a failed interactive sign-in keeps the user\'s Drive grant', () async {
    final google = _GoogleSignIn();
    when(google.signIn).thenThrow(StateError('transient'));
    when(google.disconnect).thenAnswer((_) async => null);
    when(google.signOut).thenAnswer((_) async => null);
    final datasource = GoogleDriveAppDatasource(
      log: const TestLogSink(),
      googleSignIn: google,
    );

    await expectLater(datasource.connect(), throwsA(isA<StateError>()));

    verifyNever(google.disconnect);
    verifyNever(google.signOut);
    await expectLater(
      datasource.fetchFileContent('file'),
      throwsA('unauthenticated'),
    );
  });
}
