import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/labels/labels_facade.dart';
import 'package:bb_mobile/features/wallet_metadata_backup/data/labels_bip329_wallet_metadata_contributor.dart';
import 'package:bb_mobile/features/wallet_metadata_backup/domain/entities/wallet_metadata_apply.dart';
import 'package:bb_mobile/features/wallet_metadata_backup/domain/entities/wallet_metadata_record.dart';
import 'package:bb_mobile/features/wallet_metadata_backup/domain/wallet_metadata_backup_failure.dart';
import 'package:bb_mobile/features/wallet_metadata_backup/domain/wallet_metadata_contributor.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockLabelsFacade extends Mock implements LabelsFacade {}

void main() {
  final txId = 'a' * 64;
  late _MockLabelsFacade labels;
  late LabelsBip329WalletMetadataContributor contributor;

  setUp(() {
    labels = _MockLabelsFacade();
    contributor = LabelsBip329WalletMetadataContributor(labels);
  });

  Bip329LabelRecord labelRecord({
    String type = 'tx',
    String? reference,
    String label = 'coffee',
    String? origin = '[d34db33f/84h/0h/0h]',
  }) {
    return Bip329LabelRecord(
      type: type,
      reference: reference ?? txId,
      label: label,
      origin: origin,
    );
  }

  Map<String, Object?> payload(Bip329LabelRecord record) => {
    'type': record.type,
    'ref': record.reference,
    'label': record.label,
    if (record.origin != null) 'origin': record.origin,
  };

  test('wraps complete BIP329 objects as global v1 records', () async {
    final source = labelRecord();
    when(
      () => labels.exportBip329LabelRecords(),
    ).thenAnswer((_) async => Ok([source]));

    final result = await contributor.exportRecords();

    expect(
      result,
      isA<Ok<List<WalletMetadataRecord>, WalletMetadataBackupFailure>>(),
    );
    final record =
        (result as Ok<List<WalletMetadataRecord>, WalletMetadataBackupFailure>)
            .value
            .single;
    expect(record.type, 'labels.bip329');
    expect(record.version, 1);
    expect(record.scope, {'kind': 'global'});
    expect(record.recordId, source.recordId);
    expect(record.payload, payload(source));
    expect(record.payload, isNot(contains('id')));
    expect(record.payload, isNot(contains('spendable')));
  });

  test('locks the portable natural-key identity vector', () {
    final record = labelRecord(origin: null);

    expect(
      record.recordId,
      '8f7f4e38be1d29dc7adc25ba8931a8c29413e72249646c7e1d7e661ecb2a3bee',
    );
  });

  test('maps a strict labels failure without publishing empty', () async {
    when(() => labels.exportBip329LabelRecords()).thenAnswer(
      (_) async => const Err<List<Bip329LabelRecord>, LabelFailure>(
        LabelUnexpectedFailure(),
      ),
    );

    final result = await contributor.exportRecords();

    expect(
      result,
      isA<Err<List<WalletMetadataRecord>, WalletMetadataBackupFailure>>(),
    );
    final failure =
        (result as Err<List<WalletMetadataRecord>, WalletMetadataBackupFailure>)
            .failure;
    expect(failure, isA<WalletMetadataBackupContributorFailure>());
    expect(
      (failure as WalletMetadataBackupContributorFailure).contributorType,
      'labels.bip329',
    );
  });

  test('rejects duplicate portable identities as one failed export', () async {
    when(() => labels.exportBip329LabelRecords()).thenAnswer(
      (_) async => Ok([labelRecord(), labelRecord(type: 'addr', origin: null)]),
    );

    final result = await contributor.exportRecords();

    expect(
      result,
      isA<Err<List<WalletMetadataRecord>, WalletMetadataBackupFailure>>(),
    );
  });

  test('rejects a label that exceeds one metadata record', () async {
    when(
      () => labels.exportBip329LabelRecords(),
    ).thenAnswer((_) async => Ok([labelRecord(label: 'x' * 65537)]));

    final result = await contributor.exportRecords();

    expect(
      result,
      isA<Err<List<WalletMetadataRecord>, WalletMetadataBackupFailure>>(),
    );
  });

  test('validates recovery records through labels-owned payload rules', () {
    final source = labelRecord();
    final valid = WalletMetadataRecord(
      type: 'labels.bip329',
      version: 1,
      scope: const {'kind': 'global'},
      recordId: source.recordId,
      payload: payload(source),
    );
    final invalidPayload = WalletMetadataRecord(
      type: valid.type,
      version: valid.version,
      scope: valid.scope,
      recordId: valid.recordId,
      payload: {...payload(source), 'spendable': false},
    );
    final invalidIdentity = WalletMetadataRecord(
      type: valid.type,
      version: valid.version,
      scope: valid.scope,
      recordId: 'wrong-id',
      payload: payload(source),
    );
    final invalidReference = WalletMetadataRecord(
      type: valid.type,
      version: valid.version,
      scope: valid.scope,
      recordId: valid.recordId,
      payload: {...payload(source), 'ref': 'not-a-txid'},
    );

    expect(contributor.validateRecord(valid), isA<WalletMetadataRecordValid>());
    expect(
      (contributor.validateRecord(invalidPayload)
              as WalletMetadataRecordInvalid)
          .reason,
      WalletMetadataRecordInvalidReason.invalidPayload,
    );
    expect(
      (contributor.validateRecord(invalidIdentity)
              as WalletMetadataRecordInvalid)
          .reason,
      WalletMetadataRecordInvalidReason.invalidIdentity,
    );
    expect(
      (contributor.validateRecord(invalidReference)
              as WalletMetadataRecordInvalid)
          .reason,
      WalletMetadataRecordInvalidReason.invalidPayload,
    );
  });

  test(
    'applies validated intents through the labels public boundary',
    () async {
      final source = labelRecord();
      final record = WalletMetadataRecord(
        type: 'labels.bip329',
        version: 1,
        scope: const {'kind': 'global'},
        recordId: source.recordId,
        payload: payload(source),
      );
      when(() => labels.restoreBip329LabelRecords(any())).thenAnswer(
        (_) async => Ok(
          Bip329LabelRestoreSummary(
            intendedCount: 1,
            restoredCount: 1,
            alreadyPresentCount: 0,
            preservedLocalConflictCount: 0,
            localProjectionMatchesSnapshot: true,
          ),
        ),
      );

      final result = await contributor.applyIntents(
        intents: [
          (contributor.validateRecord(record) as WalletMetadataRecordValid)
              .intent,
        ],
        context: WalletMetadataApplyContext(createdWalletRefs: const {}),
      );

      final summary = switch (result) {
        Ok(:final value) => value,
        Err(:final failure) => throw TestFailure(
          'expected Ok, got ${failure.runtimeType}',
        ),
      };
      expect(summary.restoredCount, 1);
      expect(summary.localProjectionMatchesSnapshot, isTrue);
      final captured =
          verify(
                () => labels.restoreBip329LabelRecords(captureAny()),
              ).captured.single
              as List<Bip329LabelRecord>;
      expect(payload(captured.single), payload(source));
    },
  );
}
