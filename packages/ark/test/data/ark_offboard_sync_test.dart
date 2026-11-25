import 'dart:io';

import 'package:ark/ark.dart';
import 'package:ark/ark_setup.dart';
import 'package:ark/src/data/bark_ark_client.dart';
import 'package:primitives/primitives.dart';
import 'package:test/test.dart';

import '../support/fake_native.dart';

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
  BarkArkClient build(ArkExecutionMode mode) => BarkArkClient(
    storagePath: temp.path,
    childProvider: FakeChild(),
    transactionVerifier: FakeVerifier(),
    executionPolicy: FakePolicy(),
    executionMode: mode,
    stageBudget: FakeBudget(),
    opener: native,
    preflight: FakePreflight(),
    clock: () => DateTime.utc(2026, 11, 17),
  );
  T requireOk<T>(Result<T, ArkWalletFailure> result) {
    if (result case Ok(:final value)) return value;
    fail('Expected success');
  }

  setUp(() async {
    temp = Directory.systemTemp.createTempSync('ark-offboard-sync-');
    native = FakeOpener()..offboardSession = true;
    client = build(ArkExecutionMode.foreground);
    requireOk(await client.create(config));
  });
  tearDown(() async {
    await client.close();
    temp.deleteSync(recursive: true);
  });

  test('foreground progresses offboards before onchain observation', () async {
    final stages = <String>[];
    native.afterStage = stages.add;
    final pass = requireOk(await client.synchronize(account, renew: false));
    expect(pass.failedStages, isEmpty);
    expect(stages, contains('offboards'));
    expect(stages.indexOf('offboards'), lessThan(stages.indexOf('onchain')));
  });

  test('background does not progress offboard checkpoints', () async {
    await client.close();
    client = build(ArkExecutionMode.backgroundExisting);
    final stages = <String>[];
    native.afterStage = stages.add;
    final pass = requireOk(await client.synchronize(account, renew: false));
    expect(pass.failedStages, isEmpty);
    expect(stages, isNot(contains('offboards')));
  });

  test('failed progress remains stale until foreground retries it', () async {
    native.failingStage = 'offboards';
    final failed = requireOk(await client.synchronize(account, renew: false));
    expect(failed.failedStages, contains('offboards'));
    expect(failed.snapshot.stale, isTrue);
    expect(failed.failedStageKinds, contains(ArkStage.onchain));

    native.failingStage = null;
    await client.close();
    client = build(ArkExecutionMode.backgroundExisting);
    final background = requireOk(
      await client.synchronize(account, renew: false),
    );
    expect(background.snapshot.stale, isTrue);

    await client.close();
    client = build(ArkExecutionMode.foreground);
    final recovered = requireOk(
      await client.synchronize(account, renew: false),
    );
    expect(recovered.failedStages, isEmpty);
    expect(recovered.snapshot.stale, isFalse);
  });
}
