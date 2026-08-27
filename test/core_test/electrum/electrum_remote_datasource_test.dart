import 'dart:io';

import 'package:bb_mobile/core/electrum/data/electrum_socket_connector.dart';
import 'package:bb_mobile/core/electrum/domain/value_objects/electrum_connection.dart';
import 'package:bb_mobile/core/electrum/frameworks/drift/datasources/electrum_remote_datasource.dart';
import 'package:bb_mobile/core/storage/sqlite_database.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'self_signed_electrum_server.dart';

/// The datasource must open the socket described by the resolved connection
/// instead of always forcing CA-validated TLS. These tests pin the decisions it
/// makes: the url scheme, the `validateDomain` flag, and the proxy.
///
/// The fake servers never return a real transaction, so every call ends in an
/// error. What matters is *which* error: a TLS/certificate failure means the
/// transport was wrong, anything else means we got through the socket.
void main() {
  const txid =
      'cca7507897abc89628f450e8b1e0c6fca4ec3f7b34cccf55f3f531c659ff4d79';

  late SelfSignedElectrumServer fixture;

  setUpAll(() async => fixture = await SelfSignedElectrumServer.create());
  tearDownAll(() => fixture.dispose());

  late SqliteDatabase db;
  late ElectrumRemoteDatasource datasource;

  setUp(() {
    db = SqliteDatabase(NativeDatabase.memory());
    datasource = ElectrumRemoteDatasource(
      sqlite: db,
      socketConnector: const ElectrumSocketConnector(),
    );
  });

  tearDown(() => db.close());

  ElectrumConnection connectionTo(
    String url, {
    required bool validateDomain,
    String? socks5,
  }) => ElectrumConnection(
    url: url,
    retry: 1,
    timeout: 5,
    stopGap: 20,
    validateDomain: validateDomain,
    isCustom: true,
    socks5: socks5,
  );

  Future<String> errorFor(ElectrumConnection connection) async {
    try {
      await datasource.fetch(connection: connection, txid: txid);
      return '';
    } catch (e) {
      return e.toString();
    }
  }

  test('tcp:// reaches a plain server without attempting TLS', () async {
    final server = await ServerSocket.bind('127.0.0.1', 0);
    addTearDown(server.close);
    serveElectrumStub(server);

    final error = await errorFor(
      connectionTo('tcp://127.0.0.1:${server.port}', validateDomain: true),
    );

    expect(error, isNot(contains('HandshakeException')));
  });

  test('ssl:// with validateDomain false accepts a self-signed cert', () async {
    final server = await SecureServerSocket.bind(
      '127.0.0.1',
      0,
      fixture.securityContext,
    );
    addTearDown(server.close);
    serveElectrumStub(server);

    final error = await errorFor(
      connectionTo('ssl://127.0.0.1:${server.port}', validateDomain: false),
    );

    expect(error, isNot(contains('CERTIFICATE_VERIFY_FAILED')));
    expect(error, isNot(contains('HandshakeException')));
  });

  test('ssl:// with validateDomain true rejects a self-signed cert', () async {
    final server = await SecureServerSocket.bind(
      '127.0.0.1',
      0,
      fixture.securityContext,
    );
    addTearDown(server.close);
    serveElectrumStub(server);

    final error = await errorFor(
      connectionTo('ssl://127.0.0.1:${server.port}', validateDomain: true),
    );

    expect(error, contains('CERTIFICATE_VERIFY_FAILED'));
  });

  test('a bare host:port url still defaults to TLS', () async {
    final server = await ServerSocket.bind('127.0.0.1', 0);
    addTearDown(server.close);
    serveElectrumStub(server);

    final error = await errorFor(
      connectionTo('127.0.0.1:${server.port}', validateDomain: true),
    );

    // TLS attempted against a plain socket — proves the url was not mistaken
    // for a `host` scheme by Uri.parse.
    expect(error, contains('HandshakeException'));
  });

  test('rejects an unusable proxy instead of connecting directly', () async {
    // A malformed SOCKS endpoint must abort the request. Falling through to a
    // direct connection would silently send over clearnet the traffic the
    // caller asked to route through Tor.
    final error = await errorFor(
      connectionTo(
        'ssl://127.0.0.1:1',
        validateDomain: true,
        socks5: '127.0.0.1:not-a-port',
      ),
    );

    expect(error, contains('unusable SOCKS5 proxy'));
  });
}
