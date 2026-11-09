import 'dart:async';
import 'dart:convert';
import 'package:bull_recoverbull/src/data/datasources/google_drive_datasource.dart';
import 'package:bull_recoverbull/src/data/google_drive_repository.dart';
import 'package:bull_recoverbull/bull_recoverbull.dart';
import 'package:bull_recoverbull/src/domain/entities/drive_file_metadata.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;

void main() {
  late _Google google;
  late _Client client;
  late GoogleDriveAppDatasource datasource;
  late Future<http.Client?> Function() authenticate;
  setUp(() {
    google = _Google();
    client = _Client();
    authenticate = () async => client;
    datasource = GoogleDriveAppDatasource(
      googleSignIn: google,
      authenticatedClient: () => authenticate(),
    );
  });
  tearDown(() => datasource.dispose());

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
  GoogleSignInAccount? account = _Account('first@example.invalid');
  bool failSilently = false;
  int disconnects = 0;
  @override
  GoogleSignInAccount? get currentUser => account;
  @override
  Future<GoogleSignInAccount?> signIn() async => account;
  @override
  Future<GoogleSignInAccount?> signInSilently({
    bool suppressErrors = true,
    bool reAuthenticate = false,
  }) async {
    if (failSilently) throw const FormatException('Unavailable');
    return account;
  }

  @override
  Future<GoogleSignInAccount?> disconnect() async {
    disconnects++;
    account = null;
    return null;
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
