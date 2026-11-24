import 'dart:io';

import 'package:ark/ark.dart';
import 'package:ark/ark_setup.dart';
import 'package:ark/src/data/bark_ark_client.dart';
import 'package:primitives/primitives.dart';
import 'package:test/test.dart';

import '../support/fake_native.dart';

/// Bark connects to the server lazily: a session reports server information
/// only after its server stage ran. A committed snapshot must not lose it.
void main() {
  late Directory temp;
  late FakeOpener native;
  late BarkArkClient client;
  final account = ArkAccountId(
    parent: Fingerprint('12345678'),
    network: BitcoinNetwork.regtest,
    serverIdentity: 'server',
  );
  final config = ArkAccountConfig(
    id: account,
    arkUrl: Uri.parse('http://localhost:3535'),
    primaryEsploraUrl: Uri.parse('http://localhost:3000'),
  );
  T ok<T>(Result<T, ArkWalletFailure> result) {
    if (result case Ok(:final value)) return value;
    throw StateError('Expected Ok, got $result');
  }

  setUp(() {
    temp = Directory.systemTemp.createTempSync('ark-server-info-');
    native = FakeOpener()..requireBoardServerInfo = true;
    client = BarkArkClient(
      storagePath: temp.path,
      childProvider: FakeChild(),
      transactionVerifier: FakeVerifier(),
      executionPolicy: FakePolicy(),
      executionMode: ArkExecutionMode.foreground,
      stageBudget: FakeBudget(),
      opener: native,
      preflight: FakePreflight(),
      clock: () => DateTime.utc(2026, 11, 17),
    );
  });
  tearDown(() async {
    await client.close();
    temp.deleteSync(recursive: true);
  });

  test('creating an account saves the server information', () async {
    ok(await client.create(config));
    final saved = ok(await client.read(account)).serverInfo;
    expect(saved?.publicKey, 'server-key');
    expect(saved?.minimumBoard, Sats.fromInt(1000));
  });

  test('an unreachable server still creates the account, without it', () async {
    native.failingStage = 'server';
    ok(await client.create(config));
    expect(ok(await client.read(account)).serverInfo, isNull);
  });

  test(
    'an observation without a connection keeps the saved information',
    () async {
      ok(await client.create(config));
      native.failingStage = 'server';
      ok(await client.create(config));
      final kept = ok(await client.read(account));
      expect(kept.revision, greaterThan(1));
      expect(kept.serverInfo?.publicKey, 'server-key');
      expect(kept.serverInfo?.minimumBoard, Sats.fromInt(1000));
    },
  );
}
