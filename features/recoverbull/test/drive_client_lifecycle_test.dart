import 'dart:async';
import 'dart:convert';

import 'package:bull_recoverbull/src/data/datasources/google_drive_datasource.dart';
import 'package:bull_recoverbull/src/data/google_drive_repository.dart';
import 'package:bull_recoverbull/bull_recoverbull.dart';
import 'package:bull_recoverbull/src/domain/entities/drive_file_metadata.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:google_sign_in_platform_interface/google_sign_in_platform_interface.dart';
import 'package:http/http.dart' as http;

void main() {
  late _Google google;
  late _Tokens tokens;
  late GoogleSignInPlatform previousPlatform;
  late _Client client;
  late GoogleDriveAppDatasource datasource;
  late Future<http.Client?> Function() authenticate;
  setUp(() {
    previousPlatform = GoogleSignInPlatform.instance;
    tokens = _Tokens();
    GoogleSignInPlatform.instance = tokens;
    google = _Google();
    client = _Client();
    authenticate = () async => client;
    datasource = GoogleDriveAppDatasource(
      googleSignIn: google,
      authenticatedClient: () => authenticate(),
    );
  });
  tearDown(() async {
    datasource.dispose();
    GoogleSignInPlatform.instance = previousPlatform;
    await google.events.close();
  });

  test('a sign-out invalidates the foreground client', () async {
    await datasource.connect();
    await google.signOut();
    expect(client.closes, 1);
    await expectLater(datasource.fetchAllMetadata(), throwsA(isA<Exception>()));
    expect(google.disconnects, 0);
  });

  test('silent discovery never requests interactive token recovery', () async {
    datasource.dispose();
    datasource = GoogleDriveAppDatasource(googleSignIn: google);
    tokens.accessToken = null;
    expect(await datasource.connectSilently(), isNull);
    expect(tokens.recoveryRequests, [false]);
    expect(google.signIns, 0);
    expect(google.disconnects, 0);
    await expectLater(datasource.fetchAllMetadata(), throwsA(isA<Exception>()));
  });

  test('foreground connection can authenticate interactively', () async {
    datasource.dispose();
    datasource = GoogleDriveAppDatasource(googleSignIn: google);
    await datasource.connect();
    expect(google.signIns, 1);
    expect(tokens.recoveryRequests, [true]);
    expect(google.disconnects, 0);
  });

  for (final disposed in [false, true]) {
    test('late token recovery is fenced after '
        '${disposed ? 'disposal' : 'account change'}', () async {
      datasource.dispose();
      datasource = GoogleDriveAppDatasource(googleSignIn: google);
      final pending = Completer<GoogleSignInTokenData>();
      tokens.pending = pending.future;
      final refresh = datasource.connectSilently();
      await tokens.requested.future;
      if (disposed) {
        datasource.dispose();
      } else {
        google.account = _Account('second@example.invalid');
      }
      pending.complete(
        GoogleSignInTokenData(accessToken: 'synthetic-test-token'),
      );
      expect(await refresh, isNull);
      await expectLater(
        datasource.fetchAllMetadata(),
        throwsA(disposed ? isA<StateError>() : isA<Exception>()),
      );
      expect(tokens.recoveryRequests, [false]);
      expect(google.disconnects, 0);
    });
  }

  for (final returnsAccount in [true, false]) {
    test(
      'a late silent result ($returnsAccount) cannot replace a newer account',
      () async {
        await datasource.connect();
        final first = google.account;
        final pending = Completer<GoogleSignInAccount?>();
        google.pendingSilent = pending.future;
        final refresh = datasource.connectSilently();
        await Future<void>.delayed(Duration.zero);
        google.account = _Account('second@example.invalid');
        final replacement = _Client();
        authenticate = () async => replacement;
        await datasource.connect();
        pending.complete(returnsAccount ? first : null);
        expect(await refresh, isNull);
        expect(client.closes, 1);
        expect(client.writes, 0);
        expect(replacement.closes, 0);
        expect(await datasource.fetchAllMetadata(), isEmpty);
        expect(google.disconnects, 0);
      },
    );
  }

  test('a Drive delete confirmation cannot cross an account change', () async {
    client.hasFile = true;
    final repository = GoogleDriveRepositoryImpl(datasource: datasource);
    await repository.connect();
    final files = await repository.fetchAllMetadata();
    final selected =
        (files as Ok<List<DriveFileMetadata>, RecoverBullFailure>).value.single;
    google.account = _Account('second@example.invalid');
    expect(
      await repository.trash(selected),
      isA<Err<Null, RecoverBullFailure>>(),
    );
    expect(client.writes, 0);
    repository.dispose();
  });

  test('a failed silent discovery preserves the foreground client', () async {
    await datasource.connect();
    google.failSilently = true;
    expect(await datasource.connectSilently(), isNull);
    expect(await datasource.fetchAllMetadata(), isEmpty);
    expect(client.closes, 0);
    expect(google.disconnects, 0);
  });
  test(
    'a changed account cannot retain the old client on refresh failure',
    () async {
      await datasource.connect();
      google.account = _Account('second@example.invalid');
      google.failSilently = true;
      expect(await datasource.connectSilently(), isNull);
      expect(client.closes, 1);
      await expectLater(
        datasource.fetchAllMetadata(),
        throwsA(isA<Exception>()),
      );
    },
  );
  test(
    'late authentication after disposal closes its transport once',
    () async {
      final pending = Completer<http.Client?>();
      authenticate = () => pending.future;
      final connect = datasource.connect();
      await Future<void>.delayed(Duration.zero);
      datasource.dispose();
      final rejected = expectLater(connect, throwsA(isA<Exception>()));
      pending.complete(client);
      await rejected;
      expect(client.closes, 1);
      expect(google.disconnects, 0);
    },
  );
}

final class _Account extends Fake implements GoogleSignInAccount {
  @override
  final String email;
  _Account(this.email);
}

final class _Google extends Fake implements GoogleSignIn {
  GoogleSignInAccount? _account = _Account('first@example.invalid');
  final events = StreamController<GoogleSignInAccount?>.broadcast(sync: true);
  bool failSilently = false;
  Future<GoogleSignInAccount?>? pendingSilent;
  int disconnects = 0;
  int signIns = 0;
  GoogleSignInAccount? get account => _account;
  set account(GoogleSignInAccount? value) {
    _account = value;
    events.add(value);
  }

  @override
  GoogleSignInAccount? get currentUser => account;
  @override
  List<String> get scopes => ['https://www.googleapis.com/auth/drive.appdata'];
  @override
  Stream<GoogleSignInAccount?> get onCurrentUserChanged => events.stream;
  @override
  Future<GoogleSignInAccount?> signIn() async {
    signIns++;
    final value = account;
    if (value == null) throw const FormatException('Unavailable');
    return value;
  }

  @override
  Future<GoogleSignInAccount?> signInSilently({
    bool suppressErrors = true,
    bool reAuthenticate = false,
  }) {
    final pending = pendingSilent;
    if (pending != null) return pending;
    if (failSilently) return Future.error(const FormatException('Unavailable'));
    return Future.value(account);
  }

  @override
  Future<GoogleSignInAccount?> signOut() async {
    account = null;
    return null;
  }

  @override
  Future<GoogleSignInAccount?> disconnect() async {
    disconnects++;
    account = null;
    return null;
  }
}

final class _Tokens extends GoogleSignInPlatform {
  final recoveryRequests = <bool?>[];
  String? accessToken = 'synthetic-test-token';
  Future<GoogleSignInTokenData>? pending;
  final requested = Completer<void>();
  @override
  Future<GoogleSignInTokenData> getTokens({
    required String email,
    bool? shouldRecoverAuth,
  }) async {
    recoveryRequests.add(shouldRecoverAuth);
    if (!requested.isCompleted) requested.complete();
    final pendingTokens = pending;
    if (pendingTokens != null) return await pendingTokens;
    return GoogleSignInTokenData(accessToken: accessToken);
  }
}

final class _Client extends http.BaseClient {
  int closes = 0;
  int writes = 0;
  bool hasFile = false;
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    if (request.method != 'GET') writes++;
    return http.StreamedResponse(
      Stream.value(
        utf8.encode(
          hasFile
              ? '{"files":[{"id":"file","name":"vault.json","createdTime":"2026-11-09T00:00:00Z"}]}'
              : '{"files":[]}',
        ),
      ),
      200,
      headers: {'content-type': 'application/json'},
    );
  }

  @override
  void close() {
    closes++;
  }
}
