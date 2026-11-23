import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:backup_storage/backup_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_drive/testing.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:google_sign_in_platform_interface/google_sign_in_platform_interface.dart';
import 'package:http/http.dart' as http;
import 'package:primitives/primitives.dart';

import 'support/storage_contract.dart';

void main() {
  late _Google google;
  late _Client client;
  late GoogleDriveBackupStorage storage;
  final sessions = <StorageSession>[];

  setUp(() {
    google = _Google();
    client = _Client();
    storage = GoogleDriveBackupStorage(
      open: () => openGoogleDriveForTesting(
        googleSignIn: google,
        authenticatedClient: () async => client,
      ),
    );
  });
  tearDown(() async {
    for (final session in sessions) {
      session.dispose();
    }
    sessions.clear();
    await google.events.close();
  });
  Future<StorageSession> authorize() async {
    final session = ok(await storage.authorize(interactive: false));
    sessions.add(session);
    return session;
  }

  group('Drive contract', () {
    storageContract(() => storage);
  });

  test('pages exhaust internally, metadata includes size and MD5', () async {
    final queries = <Map<String, String>>[];
    client.respond = (request) {
      queries.add(request.url.queryParameters);
      return _json({
        'files': [_metadata(request.url.queryParameters['pageToken'] ?? 'one')],
        if (queries.length == 1) 'nextPageToken': 'two',
      });
    };
    final files = ok(
      await (await authorize()).list(mimeType: 'application/json'),
    );
    expect(files.map((file) => file.id), ['one', 'two']);
    expect(files.first.size, 5);
    expect(files.first.md5, 'synthetic-md5');
    expect(files.first.durability, Durability.durable);
    expect(queries.first['fields'], contains('size'));
    expect(queries.first['fields'], contains('md5Checksum'));
    expect(queries.first['spaces'], 'appDataFolder');
    expect(queries.first['orderBy'], 'createdTime desc');
    expect(queries.first['q'], "mimeType='application/json' and trashed=false");
    expect(queries.last['pageToken'], 'two');
  });

  test('repeated page token is a modeled failure', () async {
    client.respond = (_) => _json({'files': [], 'nextPageToken': 'repeat'});
    final result = await (await authorize()).list(mimeType: 'application/json');
    expect(
      (result as Err<List<StoredObject>, BackupStorageFailure>).failure,
      isA<BackupStorageUnexpectedFailure>(),
    );
    expect(client.requests, hasLength(2));
  });

  for (final duringRead in [false, true]) {
    test(
      'account switch ${duringRead ? 'during' : 'before'} IO is fenced',
      () async {
        final session = await authorize();
        final pending = Completer<http.StreamedResponse>();
        client.pending = pending.future;
        if (!duringRead) google.account = _Account('second@example.invalid');
        final operation = session.list(mimeType: 'application/json');
        if (duringRead) {
          await Future<void>.delayed(Duration.zero);
          google.account = _Account('second@example.invalid');
          pending.complete(_json({'files': []}));
        }
        final result = await operation;
        expect(
          (result as Err<List<StoredObject>, BackupStorageFailure>).failure,
          isA<BackupStorageAuthorizationRequiredFailure>(),
        );
        expect(client.closes, 1);
        expect(google.disconnects, 0);
        expect(client.requests.length, duringRead ? 1 : 0);
      },
    );
  }

  test(
    'account fencing wins over an HTTP error caused by client closure',
    () async {
      final session = await authorize();
      final pending = Completer<http.StreamedResponse>();
      client.pending = pending.future;
      final operation = session.list(mimeType: 'application/json');
      await Future<void>.delayed(Duration.zero);
      google.account = _Account('second@example.invalid');
      pending.completeError(http.ClientException('closed'));
      final result = await operation;
      expect(
        (result as Err<List<StoredObject>, BackupStorageFailure>).failure,
        isA<BackupStorageAuthorizationRequiredFailure>(),
      );
    },
  );

  for (final creating in [true, false]) {
    test(
      'account change invalidates an in-flight ${creating ? 'create' : 'delete'}',
      () async {
        final session = await authorize();
        final pending = Completer<http.StreamedResponse>();
        client.pending = pending.future;
        final Future<Result<Object?, BackupStorageFailure>> operation;
        if (creating) {
          operation = session.create(
            name: 'file.json',
            mimeType: 'application/json',
            bytes: Uint8List.fromList([1]),
          );
        } else {
          operation = session
              .delete(_object)
              .then((result) => result.map((_) => null));
        }
        await Future<void>.delayed(Duration.zero);
        google.account = _Account('second@example.invalid');
        google.account = _Account('first@example.invalid');
        pending.complete(
          creating
              ? _json(_metadata('file'))
              : http.StreamedResponse(const Stream.empty(), 204),
        );
        expect(
          await operation,
          isA<Err<Object?, BackupStorageFailure>>().having(
            (result) => result.failure,
            'failure',
            isA<BackupStorageAuthorizationRequiredFailure>(),
          ),
        );
        expect(client.requests.single.method, creating ? 'POST' : 'DELETE');
        expect(google.disconnects, 0);
      },
    );
  }

  test('unadvertised oversized media is rejected while streaming', () async {
    final session = await authorize();
    var cancelled = false;
    final stream = StreamController<List<int>>(
      onCancel: () {
        cancelled = true;
      },
    );
    client.respond = (_) => http.StreamedResponse(
      stream.stream,
      200,
      headers: {'content-type': 'application/octet-stream'},
    );
    final operation = session.read(_object, maxBytes: 2);
    stream.add([1, 2]);
    stream.add([3]);
    final result = await operation;
    expect(
      (result as Err<Uint8List, BackupStorageFailure>).failure,
      isA<BackupStorageTooLargeFailure>(),
    );
    expect(cancelled, isTrue);
    await stream.close();
  });

  for (final (status, reason, expected) in [
    (401, 'authError', isA<BackupStorageAuthorizationRequiredFailure>()),
    (
      403,
      'insufficientPermissions',
      isA<BackupStoragePermissionRevokedFailure>(),
    ),
    (
      403,
      'appNotAuthorizedToFile',
      isA<BackupStoragePermissionRevokedFailure>(),
    ),
    (403, 'forbidden', isA<BackupStorageUnexpectedFailure>()),
    (403, 'storageQuotaExceeded', isA<BackupStorageQuotaExceededFailure>()),
    (403, 'userRateLimitExceeded', isA<BackupStorageUnavailableFailure>()),
    (404, 'notFound', isA<BackupStorageNotFoundFailure>()),
    (429, 'rateLimitExceeded', isA<BackupStorageUnavailableFailure>()),
    (503, 'backendError', isA<BackupStorageUnavailableFailure>()),
  ]) {
    test('HTTP $status/$reason maps to a safe failure', () async {
      client.respond = (_) => _json({
        'error': {
          'code': status,
          'message': 'untrusted foreign message',
          'errors': [
            {'reason': reason, 'domain': 'global'},
          ],
        },
      }, status);
      final result = await (await authorize()).list(
        mimeType: 'application/json',
      );
      final failure =
          (result as Err<List<StoredObject>, BackupStorageFailure>).failure;
      expect(failure, expected);
      expect(failure.logMessage, isNull);
    });
  }

  test('dispose releases without revoking, disconnect revokes once', () async {
    final session = await authorize();
    session.dispose();
    session.dispose();
    expect(client.closes, 1);
    expect(google.disconnects, 0);
    final second = await authorize();
    ok(await second.disconnect());
    expect(google.disconnects, 1);
  });

  test(
    'overlapping sessions release an injected client after its last use',
    () async {
      final previous = await authorize();
      final replacement = await authorize();

      previous.dispose();

      expect(client.closes, 0);
      expect(ok(await replacement.list(mimeType: 'application/json')), isEmpty);
      replacement.dispose();
      expect(client.closes, 1);
    },
  );

  test(
    'disconnect cannot queue behind another storage instance signing in',
    () async {
      final session = await authorize();
      final pending = Completer<GoogleSignInAccount?>();
      google.pendingSignIn = pending.future;
      final other = GoogleDriveBackupStorage(
        open: () => openGoogleDriveForTesting(
          googleSignIn: google,
          authenticatedClient: () async => _Client(),
        ),
      );
      final switching = other.authorize(interactive: true);
      final revoked = await session.disconnect();
      final replacement = _Account('second@example.invalid');
      google.account = replacement;
      pending.complete(replacement);
      final replacementResult = await switching;
      if (replacementResult case Ok(:final value)) value.dispose();

      expect(
        revoked,
        isA<Err<void, BackupStorageFailure>>().having(
          (result) => result.failure,
          'failure',
          isA<BackupStorageUnavailableFailure>(),
        ),
      );
      expect(google.disconnects, 0);
      expect(
        replacementResult,
        isA<Ok<StorageSession, BackupStorageFailure>>(),
      );
    },
  );

  testWidgets('authorization deadline closes a late transport', (tester) async {
    final pending = Completer<http.Client?>();
    storage = GoogleDriveBackupStorage(
      open: () => openGoogleDriveForTesting(
        googleSignIn: google,
        authenticatedClient: () => pending.future,
      ),
    );
    final operation = storage.authorize(interactive: false);
    await tester.pump();
    await tester.pump(const Duration(seconds: 61));
    final result = await operation;
    expect(
      (result as Err<StorageSession, BackupStorageFailure>).failure,
      isA<BackupStorageUnavailableFailure>(),
    );
    pending.complete(client);
    await tester.pump();
    expect(client.closes, 1);
    expect(google.disconnects, 0);
  });

  testWidgets('operation deadline invalidates its capability', (tester) async {
    final session = await authorize();
    final pending = Completer<http.StreamedResponse>();
    client.pending = pending.future;
    final operation = session.list(mimeType: 'application/json');
    await tester.pump();
    await tester.pump(const Duration(seconds: 61));
    final result = await operation;
    expect(
      (result as Err<List<StoredObject>, BackupStorageFailure>).failure,
      isA<BackupStorageUnavailableFailure>(),
    );
    expect(client.closes, 1);
    pending.complete(_json({'files': []}));
    await tester.pump();
    expect(
      await session.delete(_object),
      isA<Err<void, BackupStorageFailure>>(),
    );
  });

  test('a late authorization cannot follow a replacement account', () async {
    final pending = Completer<http.Client?>();
    storage = GoogleDriveBackupStorage(
      open: () => openGoogleDriveForTesting(
        googleSignIn: google,
        authenticatedClient: () => pending.future,
      ),
    );
    final operation = storage.authorize(interactive: false);
    await Future<void>.delayed(Duration.zero);
    google.account = _Account('second@example.invalid');
    pending.complete(client);
    final result = await operation;
    expect(
      (result as Err<StorageSession, BackupStorageFailure>).failure,
      isA<BackupStorageAuthorizationRequiredFailure>(),
    );
    expect(client.closes, 1);
    expect(google.disconnects, 0);
  });

  for (final interactive in [false, true]) {
    test(
      'missing account maps ${interactive ? 'cancellation' : 'authorization required'}',
      () async {
        google.account = null;
        final result = await storage.authorize(interactive: interactive);
        expect(
          (result as Err<StorageSession, BackupStorageFailure>).failure,
          interactive
              ? isA<BackupStorageCancelledFailure>()
              : isA<BackupStorageAuthorizationRequiredFailure>(),
        );
        expect(google.disconnects, 0);
        expect(client.requests, isEmpty);
      },
    );
  }

  test('noninteractive tokens never permit recovery UI', () async {
    final previous = GoogleSignInPlatform.instance;
    final tokens = _Tokens();
    GoogleSignInPlatform.instance = tokens;
    addTearDown(() => GoogleSignInPlatform.instance = previous);
    storage = GoogleDriveBackupStorage(
      open: () => openGoogleDriveForTesting(googleSignIn: google),
    );
    final result = await storage.authorize(interactive: false);
    expect(result, isA<Err<StorageSession, BackupStorageFailure>>());
    expect(tokens.recoveryRequests, [false]);
    expect(google.signIns, 0);
  });
}

const _object = StoredObject(
  id: 'file',
  name: 'file',
  durability: Durability.durable,
);

Map<String, Object> _metadata(String id) => {
  'id': id,
  'name': 'file.json',
  'size': '5',
  'createdTime': '2026-11-20T00:00:00Z',
  'modifiedTime': '2026-11-20T01:00:00Z',
  'md5Checksum': 'synthetic-md5',
};

http.StreamedResponse _json(Object body, [int status = 200]) =>
    http.StreamedResponse(
      Stream.value(utf8.encode(jsonEncode(body))),
      status,
      headers: {'content-type': 'application/json'},
    );

final class _Client extends http.BaseClient {
  final requests = <http.BaseRequest>[];
  final objects = <String, Map<String, Object>>{};
  final content = <String, List<int>>{};
  int nextId = 0;
  int closes = 0;
  http.StreamedResponse Function(http.BaseRequest)? respond;
  Future<http.StreamedResponse>? pending;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    requests.add(request);
    final response = respond;
    if (response != null) return response(request);
    final wait = pending;
    if (wait != null) return wait;
    final uri = request.url;
    if (request.method == 'POST') {
      final body = await request.finalize().toBytes();
      // Parse only the transport fixture's multipart framing, not payload JSON.
      final text = latin1.decode(body);
      final start = text.indexOf('{');
      final end = text.indexOf('\r\n--', start);
      final metadata =
          jsonDecode(text.substring(start, end)) as Map<String, dynamic>;
      final mediaStart = text.indexOf('\r\n\r\n', end + 4) + 4;
      final mediaEnd = text.indexOf('\r\n--', mediaStart);
      final id = 'object-${nextId++}';
      content[id] = base64Decode(text.substring(mediaStart, mediaEnd));
      objects[id] = {
        ..._metadata(id),
        'name': metadata['name'] as String,
        'mimeType': metadata['mimeType'] as String,
        'size': '${content[id]?.length}',
      };
      return _json(objects[id] ?? {});
    }
    final id = uri.pathSegments.last;
    if (request.method == 'DELETE') {
      objects.remove(id);
      content.remove(id);
      return http.StreamedResponse(const Stream.empty(), 204);
    }
    if (uri.queryParameters['alt'] == 'media') {
      final bytes = content[id];
      return bytes == null
          ? _json({
              'error': {'code': 404, 'message': 'missing'},
            }, 404)
          : http.StreamedResponse(
              Stream.value(bytes),
              200,
              headers: {'content-type': 'application/octet-stream'},
            );
    }
    final query = uri.queryParameters['q'] ?? '';
    return _json({
      'files': objects.values
          .where((item) => query.contains("mimeType='${item['mimeType']}'"))
          .toList(),
    });
  }

  @override
  void close() => closes++;
}

final class _Account extends Fake implements GoogleSignInAccount {
  @override
  final String email;
  _Account(this.email);
}

final class _Google extends Fake implements GoogleSignIn {
  GoogleSignInAccount? _account = _Account('first@example.invalid');
  final events = StreamController<GoogleSignInAccount?>.broadcast(sync: true);
  int disconnects = 0;
  int signIns = 0;
  Future<GoogleSignInAccount?>? pendingSignIn;
  set account(GoogleSignInAccount? value) {
    _account = value;
    events.add(value);
  }

  @override
  GoogleSignInAccount? get currentUser => _account;
  @override
  Stream<GoogleSignInAccount?> get onCurrentUserChanged => events.stream;
  @override
  Future<GoogleSignInAccount?> signIn() async {
    signIns++;
    final pending = pendingSignIn;
    if (pending != null) return pending;
    return _account;
  }

  @override
  Future<GoogleSignInAccount?> signInSilently({
    bool suppressErrors = true,
    bool reAuthenticate = false,
  }) async => _account;
  @override
  Future<GoogleSignInAccount?> disconnect() async {
    disconnects++;
    account = null;
    return null;
  }
}

final class _Tokens extends GoogleSignInPlatform {
  final recoveryRequests = <bool?>[];
  @override
  Future<GoogleSignInTokenData> getTokens({
    required String email,
    bool? shouldRecoverAuth,
  }) async {
    recoveryRequests.add(shouldRecoverAuth);
    return GoogleSignInTokenData();
  }
}
