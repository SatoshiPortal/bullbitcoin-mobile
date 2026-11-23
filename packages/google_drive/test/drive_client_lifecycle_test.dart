import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:google_drive/google_drive.dart';
import 'package:google_drive/testing.dart';
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
    drive = openGoogleDriveForTesting(
      googleSignIn: google,
      authenticatedClient: () => authenticate(),
    );
  });
  tearDown(() async {
    drive.dispose();
    GoogleSignInPlatform.instance = previousPlatform;
    await google.events.close();
  });

  test('a Drive page arriving after an account change is discarded', () async {
    final requested = Completer<void>();
    final response = Completer<http.StreamedResponse>();
    client.respond = (_) {
      requested.complete();
      return response.future;
    };

    expect(await drive.connect(), isA<Ok<void, GoogleDriveFailure>>());
    final listing = drive.listFiles();
    await requested.future;

    google.account = _Account('second@example.invalid');
    response.complete(
      _jsonResponse({
        'nextPageToken': 'more-files',
        'files': [
          {
            'id': 'first-account-file',
            'name': 'example.txt',
            'createdTime': '2026-11-09T00:00:00Z',
          },
        ],
      }),
    );

    expect(
      await listing,
      isA<Err<List<GoogleDriveFileMetadata>, GoogleDriveFailure>>(),
    );
  });

  test('lists arbitrary MIME types with an escaped app-folder query', () async {
    expect(await drive.connect(), isA<Ok<void, GoogleDriveFailure>>());
    client.respond = (request) async {
      expect(request.url.queryParameters['spaces'], 'appDataFolder');
      expect(
        request.url.queryParameters['q'],
        r"mimeType='text/plain;key=\'value' and trashed=false",
      );
      return _jsonResponse({'files': []});
    };

    expect(
      await drive.listFiles(mimeType: "text/plain;key='value"),
      isA<Ok<List<GoogleDriveFileMetadata>, GoogleDriveFailure>>(),
    );
  });

  test('writes arbitrary app-folder bytes and deletes by file id', () async {
    expect(await drive.connect(), isA<Ok<void, GoogleDriveFailure>>());
    final requests = <http.BaseRequest>[];
    client.respond = (request) async {
      requests.add(request);
      if (request.method == 'POST') {
        final body = utf8.decode(await request.finalize().toBytes());
        expect(body, contains('"parents":["appDataFolder"]'));
        expect(body, contains('"mimeType":"text/plain"'));
        expect(body, contains('"name":"example.txt"'));
        expect(
          body,
          contains(base64.encode(utf8.encode('test document bytes'))),
        );
        return _jsonResponse({'id': 'test-file'});
      }
      return http.StreamedResponse(const Stream.empty(), 204);
    };

    expect(
      await drive.writeFile(
        filename: 'example.txt',
        bytes: utf8.encode('test document bytes'),
        mimeType: 'text/plain',
      ),
      isA<Ok<void, GoogleDriveFailure>>(),
    );
    expect(
      await drive.deleteFile('test-file'),
      isA<Ok<void, GoogleDriveFailure>>(),
    );
    expect(requests.map((request) => request.method), ['POST', 'DELETE']);
    expect(requests.last.url.pathSegments.last, 'test-file');
  });

  test('rejects a download exceeding its caller-supplied limit', () async {
    expect(await drive.connect(), isA<Ok<void, GoogleDriveFailure>>());
    client.respond = (request) async {
      expect(request.url.queryParameters['alt'], 'media');
      return http.StreamedResponse(
        Stream.fromIterable([
          [1, 2],
          [3, 4],
        ]),
        200,
        headers: {'content-type': 'application/octet-stream'},
      );
    };

    expect(
      await drive.readFile(fileId: 'file-id', maxBytes: 3),
      isA<Err<List<int>, GoogleDriveFailure>>().having(
        (result) => result.failure,
        'failure',
        isA<GoogleDriveTooLargeFailure>(),
      ),
    );
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

  test(
    'explicit revocation clears the account and closes its transport',
    () async {
      expect(await drive.connect(), isA<Ok<void, GoogleDriveFailure>>());
      expect(google.disconnects, 0);

      expect(await drive.revokeAccess(), isA<Ok<void, GoogleDriveFailure>>());
      expect(google.disconnects, 1);
      expect(google.currentUser, isNull);
      expect(client.closes, 1);
      client.respond = (_) =>
          fail('the revoked account must not send requests');
      expect(
        await drive.listFiles(),
        isA<Err<List<GoogleDriveFileMetadata>, GoogleDriveFailure>>().having(
          (result) => result.failure,
          'failure',
          isA<GoogleDriveUnavailableFailure>(),
        ),
      );

      drive.dispose();
      expect(google.disconnects, 1);
      expect(client.closes, 1);
    },
  );

  test('silent sign-in returns the account without prompting', () async {
    drive.dispose();
    drive = openGoogleDriveForTesting(googleSignIn: google);

    expect(
      await drive.connectSilently(),
      isA<Ok<String?, GoogleDriveFailure>>().having(
        (result) => result.value,
        'account',
        'first@example.invalid',
      ),
    );
    expect(tokens.recoveryRequests, [false]);
    expect(google.signIns, 0);
    expect(google.disconnects, 0);
  });

  test('silent discovery never requests interactive token recovery', () async {
    drive.dispose();
    drive = openGoogleDriveForTesting(googleSignIn: google);
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
    drive = openGoogleDriveForTesting(googleSignIn: google);
    expect(await drive.connect(), isA<Ok<void, GoogleDriveFailure>>());
    expect(google.signIns, 1);
    expect(tokens.recoveryRequests, [true]);
    expect(google.disconnects, 0);
  });

  for (final disposed in [false, true]) {
    test('late token recovery is fenced after '
        '${disposed ? 'disposal' : 'account change'}', () async {
      drive.dispose();
      drive = openGoogleDriveForTesting(googleSignIn: google);
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
          (result) => result.failure,
          'failure',
          disposed
              ? isA<GoogleDriveDisposedFailure>()
              : isA<GoogleDriveUnavailableFailure>(),
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

http.StreamedResponse _jsonResponse(Map<String, Object> body) =>
    http.StreamedResponse(
      Stream.value(utf8.encode(jsonEncode(body))),
      200,
      headers: {'content-type': 'application/json'},
    );

final class _Client extends http.BaseClient {
  int closes = 0;
  int writes = 0;
  Future<http.StreamedResponse> Function(http.BaseRequest)? respond;
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    if (request.method != 'GET') writes++;
    final handler = respond;
    return handler == null
        ? _jsonResponse({'files': []})
        : await handler(request);
  }

  @override
  void close() {
    closes++;
  }
}
