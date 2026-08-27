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
    ),
  ],
);

void main() {
  late PayjoinDatabase database;

  setUp(() {
    database = PayjoinDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() => database.close());

  test('imports sessions with a verified marker', () async {
    final source = _LegacyData(_snapshot());

    await importLegacyPayjoinData(database, source);

    expect(await database.select(database.payjoinSenders).get(), hasLength(1));
    expect(
      await database.select(database.payjoinReceivers).get(),
      hasLength(1),
    );
    final marker = await database
        .select(database.payjoinMigrations)
        .getSingle();
    expect(marker.sourceSchemaVersion, 14);
    expect(marker.senderCount, 1);
    expect(marker.receiverCount, 1);
    expect(marker.verificationDigest, hasLength(64));
  });

  test('imported sessions start un-aborted', () async {
    // The root schema never shipped is_aborted, so there is nothing to carry
    // over: every imported session must land on the un-aborted default.
    await importLegacyPayjoinData(database, _LegacyData(_snapshot()));

    final sender = await database.select(database.payjoinSenders).getSingle();
    final receiver = await database
        .select(database.payjoinReceivers)
        .getSingle();
    expect(sender.isAborted, isFalse);
    expect(receiver.isAborted, isFalse);
  });

  test('seeds the policy row from the defaults', () async {
    // The root settings payjoin columns only existed in the unreleased schema
    // 14, so no install carries a stored preference: the store's single row is
    // created from the conservative defaults, payjoin disabled.
    await importLegacyPayjoinData(database, _LegacyData(_snapshot()));

    final policy = await database.select(database.payjoinPolicies).getSingle();
    final defaults = PayjoinPolicy.defaults();
    expect(policy.enabled, defaults.enabled);
    expect(policy.enabled, isFalse);
    expect(policy.minimumAmountSat, defaults.minimumAmount.value.toInt());
    expect(policy.sessionLifetimeSeconds, defaults.sessionLifetime.inSeconds);
  });

  test('does not re-import after the verified marker exists', () async {
    final source = _LegacyData(_snapshot());
    await importLegacyPayjoinData(database, source);
    source.snapshot = PayjoinLegacySnapshot(
      sourceSchemaVersion: 14,
      senders: const [],
      receivers: const [],
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
    );

    await importLegacyPayjoinData(database, source);

    final policy = await database.select(database.payjoinPolicies).getSingle();
    expect(policy.enabled, isFalse);
    expect(source.reads, 1);
  });

  test(
    'audit reproducer (H5): invalid rows are quarantined, not fatal',
    () async {
      final valid = _snapshot();
      final source = _LegacyData(
        PayjoinLegacySnapshot(
          sourceSchemaVersion: valid.sourceSchemaVersion,
          // Duplicate uri: one corrupt row must not brick the whole import —
          // the caller maps any throw to a permanent migration failure, and
          // reservedOutpoints() gates coin selection app-wide.
          senders: [valid.senders.single, valid.senders.single],
          receivers: valid.receivers,
        ),
      );

      await importLegacyPayjoinData(database, source);

      expect(
        await database.select(database.payjoinSenders).get(),
        hasLength(1),
      );
      expect(
        await database.select(database.payjoinReceivers).get(),
        hasLength(1),
      );
      expect(
        await database.select(database.payjoinPolicies).get(),
        hasLength(1),
      );
      final marker = await database
          .select(database.payjoinMigrations)
          .getSingle();
      expect(marker.senderCount, 1);
      expect(marker.receiverCount, 1);
    },
  );

  test('quarantines rows with blank ids or non-positive expiry', () async {
    final valid = _snapshot();
    final badSender = PayjoinLegacySender(
      uri: 'bitcoin:bad?pj=https://payjo.in/bad',
      isTestnet: false,
      protocolState: '[]',
      walletId: ' ',
      originalPsbt: 'psbt',
      originalTransactionId: 'tx',
      amountSat: 1,
      createdAt: 1,
      expireAfterSec: 86400,
      proposalPsbt: null,
      transactionId: null,
      isExpired: false,
      isCompleted: false,
    );
    final badReceiver = PayjoinLegacyReceiver(
      id: 'bad-receiver',
      address: 'bc1qbad',
      isTestnet: false,
      protocolState: '[]',
      walletId: 'wallet',
      payjoinUri: 'bitcoin:bad?pj=https://payjo.in/bad',
      maximumFeeRateSatPerVbyte: BigInt.from(1),
      createdAt: 1,
      expireAfterSec: 0,
      originalTransaction: null,
      originalTransactionId: null,
      amountSat: null,
      proposalPsbt: null,
      transactionId: null,
      isExpired: false,
      isCompleted: false,
    );
    final source = _LegacyData(
      PayjoinLegacySnapshot(
        sourceSchemaVersion: valid.sourceSchemaVersion,
        senders: [valid.senders.single, badSender],
        receivers: [valid.receivers.single, badReceiver],
      ),
    );

    await importLegacyPayjoinData(database, source);

    expect(await database.select(database.payjoinSenders).get(), hasLength(1));
    expect(
      await database.select(database.payjoinReceivers).get(),
      hasLength(1),
    );
  });
}
