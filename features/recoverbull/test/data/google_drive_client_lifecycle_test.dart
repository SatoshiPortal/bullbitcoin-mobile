import 'dart:async';
import 'dart:convert';

import 'package:bull_recoverbull/src/data/datasources/google_drive_datasource.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:mocktail/mocktail.dart';

import '../support/log_sink.dart';

class _Google extends Mock implements GoogleSignIn {}

class _Account extends Mock implements GoogleSignInAccount {}

class _Client extends http.BaseClient {
  int closes = 0;
  int requests = 0;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    if (closes > 0) throw StateError('Closed client reused');
    requests++;
    return http.StreamedResponse(
      Stream.value(utf8.encode('{"files":[]}')),
      200,
      headers: {'content-type': 'application/json'},
    );
  }

  @override
  void close() {
    closes++;
  }
}

void main() {
  late _Google google;
  late _Account account;
  late _Client first;
  late Future<http.Client?> Function() clientFactory;
  late GoogleDriveAppDatasource datasource;

  setUp(() {
    google = _Google();
    account = _Account();
    first = _Client();
    when(() => account.email).thenReturn('first@example.test');
    when(() => google.currentUser).thenReturn(account);
    when(google.signIn).thenAnswer((_) async => account);
    when(
      () => google.signInSilently(suppressErrors: false),
    ).thenAnswer((_) async => account);
    when(google.disconnect).thenAnswer((_) async => null);
    clientFactory = () async => first;
    datasource = GoogleDriveAppDatasource(
      log: const TestLogSink(),
      googleSignIn: google,
      authenticatedClient: () => clientFactory(),
    );
  });

  tearDown(() => datasource.dispose());

  test(
    'a failed silent probe preserves the foreground authenticated client',
    () async {
      await datasource.connect();
      when(
        () => google.signInSilently(suppressErrors: false),
      ).thenThrow(Exception('transient'));
      expect(await datasource.connectSilently(), isNull);
      expect(await datasource.fetchAllMetadata(), isEmpty);
      expect(first.closes, 0);
      expect(first.requests, 1);
      verifyNever(google.disconnect);
      verifyNever(google.signOut);
    },
  );

  test(
    'a transient probe cannot preserve a client after the account changed',
    () async {
      await datasource.connect();
      final other = _Account();
      when(() => other.email).thenReturn('second@example.test');
      when(() => google.currentUser).thenReturn(other);
      when(
        () => google.signInSilently(suppressErrors: false),
      ).thenThrow(Exception('transient'));
      expect(await datasource.connectSilently(), isNull);
      expect(first.closes, 1);
      await expectLater(
        datasource.fetchAllMetadata(),
        throwsA(isA<Exception>()),
      );
    },
  );

  test(
    'a missing refreshed client preserves the same-account foreground client',
    () async {
      await datasource.connect();
      clientFactory = () async => null;
      expect(await datasource.connectSilently(), isNull);
      expect(await datasource.fetchAllMetadata(), isEmpty);
      expect(first.closes, 0);
    },
  );

  test(
    'a changed account cannot fall back to the previous account client',
    () async {
      await datasource.connect();
      final other = _Account();
      when(() => other.email).thenReturn('second@example.test');
      when(
        () => google.signInSilently(suppressErrors: false),
      ).thenAnswer((_) async => other);
      clientFactory = () async => throw Exception('refresh failed');
      expect(await datasource.connectSilently(), isNull);
      expect(first.closes, 1);
      await expectLater(
        datasource.fetchAllMetadata(),
        throwsA(isA<Exception>()),
      );
    },
  );

  test('an actual sign-out closes the old account client', () async {
    await datasource.connect();
    when(
      () => google.signInSilently(suppressErrors: false),
    ).thenAnswer((_) async => null);
    expect(await datasource.connectSilently(), isNull);
    expect(first.closes, 1);
    await expectLater(datasource.fetchAllMetadata(), throwsA(isA<Exception>()));
  });

  test(
    'refreshes close each replaced transport and disposal does not revoke grants',
    () async {
      await datasource.connect();
      final second = _Client();
      clientFactory = () async => second;
      expect(await datasource.connectSilently(), 'first@example.test');
      expect(first.closes, 1);
      expect(second.closes, 0);
      await datasource.connectSilently();
      expect(second.closes, 0);
      datasource.dispose();
      datasource.dispose();
      expect(first.closes, 1);
      expect(second.closes, 1);
      verifyNever(google.disconnect);
      verifyNever(google.signOut);
    },
  );

  test('an account change while refreshing closes both transports', () async {
    await datasource.connect();
    final pending = Completer<http.Client?>();
    clientFactory = () => pending.future;
    final refresh = datasource.connectSilently();
    await Future<void>.delayed(Duration.zero);
    final other = _Account();
    when(() => other.email).thenReturn('second@example.test');
    when(() => google.currentUser).thenReturn(other);
    final second = _Client();
    pending.complete(second);
    expect(await refresh, isNull);
    expect(first.closes, 1);
    expect(second.closes, 1);
    await expectLater(datasource.fetchAllMetadata(), throwsA(isA<Exception>()));
  });

  test(
    'disposal while authentication is pending closes the late transport',
    () async {
      final pending = Completer<http.Client?>();
      clientFactory = () => pending.future;
      final connect = datasource.connect();
      await Future<void>.delayed(Duration.zero);
      datasource.dispose();
      final expectation = expectLater(connect, throwsA(isA<Exception>()));
      pending.complete(first);
      await expectation;
      expect(first.closes, 1);
      verifyNever(google.disconnect);
    },
  );
}
