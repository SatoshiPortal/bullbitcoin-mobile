import 'package:bull_payjoin/bull_payjoin.dart';
import 'package:bull_payjoin/src/data/payjoin_database.dart';
import 'package:bull_payjoin/src/data/payjoin_migration.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:test/test.dart';

final class _LegacyData implements PayjoinLegacyDataPort {
  PayjoinLegacySnapshot snapshot;
  int reads = 0;

  _LegacyData(this.snapshot);

  @override
  Future<PayjoinLegacySnapshot> readSnapshot() async {
    reads++;
    return snapshot;
  }
}

PayjoinLegacySnapshot _snapshot() => PayjoinLegacySnapshot(
  sourceSchemaVersion: 14,
  senders: [
    PayjoinLegacySender(
      uri: 'bitcoin:sender?pj=https://payjo.in/sender',
      isTestnet: false,
      protocolState: '[{"sender":1}]',
      walletId: 'sender-wallet',
      originalPsbt: 'sender-psbt',
      originalTransactionId: 'sender-original',
      amountSat: 50000,
      createdAt: 100,
      expireAfterSec: 86400,
      proposalPsbt: 'proposal',
      transactionId: 'payjoin-tx',
      isExpired: false,
      isCompleted: true,
      isAborted: false,
    ),
  ],
  receivers: [
    PayjoinLegacyReceiver(
      id: 'receiver-id',
      address: 'bc1qreceiver',
      isTestnet: false,
      protocolState: '[{"receiver":1}]',
      walletId: 'receiver-wallet',
      payjoinUri: 'bitcoin:receiver?pj=https://payjo.in/receiver',
      maximumFeeRateSatPerVbyte: BigInt.from(10),
      createdAt: 200,
      expireAfterSec: 3600,
      originalTransaction: Uint8List.fromList([1, 2, 3]),
      originalTransactionId: 'receiver-original',
      amountSat: 75000,
      proposalPsbt: null,
      transactionId: null,
      isExpired: false,
      isCompleted: false,
      isAborted: true,
    ),
  ],
  policy: const PayjoinLegacyPolicy(
    enabled: true,
    minimumAmountSat: 12000,
    sessionLifetimeSeconds: 7200,
  ),
);

void main() {
  late PayjoinDatabase database;

  setUp(() {
    database = PayjoinDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() => database.close());

  test('imports sessions and policy with a verified marker', () async {
    final source = _LegacyData(_snapshot());

    await importLegacyPayjoinData(database, source);

    expect(await database.select(database.payjoinSenders).get(), hasLength(1));
    expect(
      await database.select(database.payjoinReceivers).get(),
      hasLength(1),
    );
    final policy = await database.select(database.payjoinPolicies).getSingle();
    expect(policy.enabled, isTrue);
    expect(policy.minimumAmountSat, 12000);
    expect(policy.sessionLifetimeSeconds, 7200);
    final marker = await database
        .select(database.payjoinMigrations)
        .getSingle();
    expect(marker.sourceSchemaVersion, 14);
    expect(marker.senderCount, 1);
    expect(marker.receiverCount, 1);
    expect(marker.verificationDigest, hasLength(64));
  });

  test('does not re-import after the verified marker exists', () async {
    final source = _LegacyData(_snapshot());
    await importLegacyPayjoinData(database, source);
    source.snapshot = PayjoinLegacySnapshot(
      sourceSchemaVersion: 14,
      senders: const [],
      receivers: const [],
      policy: source.snapshot.policy,
    );

    await importLegacyPayjoinData(database, source);

    expect(await database.select(database.payjoinSenders).get(), hasLength(1));
    expect(
      await database.select(database.payjoinReceivers).get(),
      hasLength(1),
    );
    expect(source.reads, 1);
  });

  test('accepts legitimate package data changes after migration', () async {
    final source = _LegacyData(_snapshot());
    await importLegacyPayjoinData(database, source);
    await database
        .update(database.payjoinPolicies)
        .write(const PayjoinPoliciesCompanion(enabled: Value(false)));
    source.snapshot = PayjoinLegacySnapshot(
      sourceSchemaVersion: 14,
      senders: const [],
      receivers: const [],
      policy: source.snapshot.policy,
    );

    await importLegacyPayjoinData(database, source);

    final policy = await database.select(database.payjoinPolicies).getSingle();
    expect(policy.enabled, isFalse);
    expect(source.reads, 1);
  });

  test('rolls back every target write when validation fails', () async {
    final valid = _snapshot();
    final source = _LegacyData(
      PayjoinLegacySnapshot(
        sourceSchemaVersion: valid.sourceSchemaVersion,
        senders: [valid.senders.single, valid.senders.single],
        receivers: valid.receivers,
        policy: valid.policy,
      ),
    );

    await expectLater(
      importLegacyPayjoinData(database, source),
      throwsStateError,
    );

    expect(await database.select(database.payjoinSenders).get(), isEmpty);
    expect(await database.select(database.payjoinReceivers).get(), isEmpty);
    expect(await database.select(database.payjoinPolicies).get(), isEmpty);
    expect(await database.select(database.payjoinMigrations).get(), isEmpty);
  });
}
