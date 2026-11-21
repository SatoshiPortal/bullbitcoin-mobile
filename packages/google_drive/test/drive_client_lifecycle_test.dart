import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:google_drive/google_drive.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:google_sign_in_platform_interface/google_sign_in_platform_interface.dart';
import 'package:http/http.dart' as http;
import 'package:primitives/primitives.dart';

void main() {
  late _Google google;
  late _Tokens tokens;
  late GoogleSignInPlatform previousPlatform;
  late _Client client;
  late GoogleDrive drive;
  late Future<http.Client?> Function() authenticate;
  setUp(() {
    previousPlatform = GoogleSignInPlatform.instance;
    tokens = _Tokens();
    GoogleSignInPlatform.instance = tokens;
    google = _Google();
    client = _Client();
    authenticate = () async => client;
    drive = GoogleDrive(
      googleSignIn: google,
      authenticatedClient: () => authenticate(),
    );
  });
  tearDown(() async {
    drive.dispose();
    GoogleSignInPlatform.instance = previousPlatform;
    await google.events.close();
  });

  test('a sign-out invalidates the foreground client', () async {
    expect(await drive.connect(), isA<Ok<void, GoogleDriveFailure>>());
    await google.signOut();
    expect(client.closes, 1);
    expect(
      await drive.listFiles(),
      isA<Err<List<GoogleDriveFileMetadata>, GoogleDriveFailure>>(),
    );
    expect(google.disconnects, 0);
  });

  test('silent discovery never requests interactive token recovery', () async {
    drive.dispose();
    drive = GoogleDrive(googleSignIn: google);
    tokens.accessToken = null;
    expect(
      (await drive.connectSilently()).fold(
        (value) => value,
        (_) => fail('silent sign-in failed'),
      ),
      isNull,
    );
    expect(tokens.recoveryRequests, [false]);
    expect(google.signIns, 0);
    expect(google.disconnects, 0);
    expect(
      await drive.listFiles(),
      isA<Err<List<GoogleDriveFileMetadata>, GoogleDriveFailure>>(),
    );
  });

  test('foreground connection can authenticate interactively', () async {
    drive.dispose();
    drive = GoogleDrive(googleSignIn: google);
    expect(await drive.connect(), isA<Ok<void, GoogleDriveFailure>>());
    expect(google.signIns, 1);
    expect(tokens.recoveryRequests, [true]);
    expect(google.disconnects, 0);
  });

  for (final disposed in [false, true]) {
    test('late token recovery is fenced after '
        '${disposed ? 'disposal' : 'account change'}', () async {
      drive.dispose();
      drive = GoogleDrive(googleSignIn: google);
      final pending = Completer<GoogleSignInTokenData>();
      tokens.pending = pending.future;
      final refresh = drive.connectSilently();
      await tokens.requested.future;
      if (disposed) {
        drive.dispose();
      } else {
        google.account = _Account('second@example.invalid');
      }
      pending.complete(
        GoogleSignInTokenData(accessToken: 'synthetic-test-token'),
      );
      expect(await refresh, isA<Err<String?, GoogleDriveFailure>>());
      expect(
        await drive.listFiles(),
        isA<Err<List<GoogleDriveFileMetadata>, GoogleDriveFailure>>().having(
          (result) => result.failure.kind,
          'failure kind',
          disposed
              ? GoogleDriveFailureKind.disposed
              : GoogleDriveFailureKind.unavailable,
        ),
      );
      expect(tokens.recoveryRequests, [false]);
      expect(google.disconnects, 0);
    });
  }

  for (final returnsAccount in [true, false]) {
    test(
      'a late silent result ($returnsAccount) cannot replace a newer account',
      () async {
        expect(await drive.connect(), isA<Ok<void, GoogleDriveFailure>>());
        final first = google.account;
        final pending = Completer<GoogleSignInAccount?>();
        google.pendingSilent = pending.future;
        final refresh = drive.connectSilently();
        await Future<void>.delayed(Duration.zero);
        google.account = _Account('second@example.invalid');
        final replacement = _Client();
        authenticate = () async => replacement;
        expect(await drive.connect(), isA<Ok<void, GoogleDriveFailure>>());
        pending.complete(returnsAccount ? first : null);
        expect(await refresh, isA<Err<String?, GoogleDriveFailure>>());
        expect(client.closes, 1);
        expect(client.writes, 0);
        expect(replacement.closes, 0);
        expect(
          (await drive.listFiles()).fold(
            (value) => value,
            (_) => fail('listing files failed'),
          ),
          isEmpty,
        );
        expect(google.disconnects, 0);
      },
    );
  }

  test('a failed silent discovery preserves the foreground client', () async {
    expect(await drive.connect(), isA<Ok<void, GoogleDriveFailure>>());
    google.failSilently = true;
    expect(
      await drive.connectSilently(),
      isA<Err<String?, GoogleDriveFailure>>(),
    );
    expect(
      (await drive.listFiles()).fold(
        (value) => value,
        (_) => fail('listing files failed'),
      ),
      isEmpty,
    );
    expect(client.closes, 0);
    expect(google.disconnects, 0);
  });
  test(
    'a changed account cannot retain the old client on refresh failure',
    () async {
      expect(await drive.connect(), isA<Ok<void, GoogleDriveFailure>>());
      google.account = _Account('second@example.invalid');
      google.failSilently = true;
      expect(
        await drive.connectSilently(),
        isA<Err<String?, GoogleDriveFailure>>(),
      );
      expect(client.closes, 1);
      expect(
        await drive.listFiles(),
        isA<Err<List<GoogleDriveFileMetadata>, GoogleDriveFailure>>(),
      );
    },
  );
  test(
    'late authentication after disposal closes its transport once',
    () async {
      final pending = Completer<http.Client?>();
      authenticate = () => pending.future;
      final connect = drive.connect();
      await Future<void>.delayed(Duration.zero);
      drive.dispose();

      pending.complete(client);
      expect(await connect, isA<Err<void, GoogleDriveFailure>>());
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
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    if (request.method != 'GET') writes++;
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
