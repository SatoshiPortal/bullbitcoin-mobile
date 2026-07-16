import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/domain/entities/frozen_wallet_outpoint.dart';
import 'package:bb_mobile/core/wallet/domain/repositories/wallet_utxo_repository.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/get_frozen_wallet_outpoints_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/restore_frozen_wallet_outpoints_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/watch_wallet_utxo_freeze_changes_usecase.dart';
import 'package:bb_mobile/features/wallet_metadata_backup/data/wallet_metadata_snapshot_codec.dart';
import 'package:bb_mobile/features/wallet_metadata_backup/data/wallet_utxo_freeze_metadata_contributor.dart';
import 'package:bb_mobile/features/wallet_metadata_backup/domain/entities/wallet_metadata_apply.dart';
import 'package:bb_mobile/features/wallet_metadata_backup/domain/entities/wallet_metadata_record.dart';
import 'package:bb_mobile/features/wallet_metadata_backup/domain/wallet_metadata_backup_failure.dart';
import 'package:bb_mobile/features/wallet_metadata_backup/domain/wallet_metadata_contributor.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockWalletUtxoRepository extends Mock implements WalletUtxoRepository {}

void main() {
  final txId = 'a' * 64;
  late _MockWalletUtxoRepository repository;
  late WalletUtxoFreezeMetadataContributor contributor;

  setUp(() {
    repository = _MockWalletUtxoRepository();
    contributor = WalletUtxoFreezeMetadataContributor(
      GetFrozenWalletOutpointsUsecase(repository),
      RestoreFrozenWalletOutpointsUsecase(repository),
      WatchWalletUtxoFreezeChangesUsecase(repository),
    );
  });

  test(
    'preserves an exact wallet id without BIP329 origin reduction',
    () async {
      const walletId = 'elwpkh([0f36572d/84h/1h/0h])';
      when(() => repository.getAllFrozenWalletOutpoints()).thenAnswer(
        (_) async => [
          FrozenWalletOutpoint(walletId: walletId, txId: txId, vout: 3),
        ],
      );

      final result = await contributor.exportRecords();

      final record = _requireOk(result).single;
      expect(record.type, 'wallet.utxo_freeze');
      expect(record.version, 1);
      expect(record.scope, {'kind': 'wallet', 'walletRef': walletId});
      expect(record.recordId, '$txId:3');
      expect(record.payload, {
        'walletRef': walletId,
        'txid': txId,
        'vout': 3,
        'frozen': true,
      });
      expect(record.payload, isNot(contains('origin')));
      expect(record.payload, isNot(contains('spendable')));
    },
  );

  test('keeps an unattributed row explicit and inert', () async {
    when(() => repository.getAllFrozenWalletOutpoints()).thenAnswer(
      (_) async => [FrozenWalletOutpoint(walletId: '', txId: txId, vout: 0)],
    );

    final record = _requireOk(await contributor.exportRecords()).single;

    expect(record.scope, {'kind': 'unattributed'});
    expect(record.payload['walletRef'], '');
    expect(record.recordId, '$txId:0');
  });

  test(
    'same outpoint under exact distinct attributions remains lossless',
    () async {
      when(() => repository.getAllFrozenWalletOutpoints()).thenAnswer(
        (_) async => [
          FrozenWalletOutpoint(walletId: 'wallet-a', txId: txId, vout: 1),
          FrozenWalletOutpoint(walletId: 'wallet-b', txId: txId, vout: 1),
        ],
      );

      final records = _requireOk(await contributor.exportRecords());

      expect(records, hasLength(2));
      expect(records.map((record) => record.recordId).toSet(), {'$txId:1'});
      expect(records.map((record) => record.scope['walletRef']).toSet(), {
        'wallet-a',
        'wallet-b',
      });
    },
  );

  test(
    'generic record codec round-trips the complete freeze payload',
    () async {
      const walletId = 'wsh(sortedmulti(2,[aaaa/48h/0h/0h/2h]xpub...))';
      when(() => repository.getAllFrozenWalletOutpoints()).thenAnswer(
        (_) async => [
          FrozenWalletOutpoint(walletId: walletId, txId: txId, vout: 4),
        ],
      );
      const codec = WalletMetadataSnapshotCodec();
      final source = _requireOk(await contributor.exportRecords()).single;

      final decoded = codec.decodeRecord(codec.encodeRecord(source));

      expect(decoded.scope, source.scope);
      expect(decoded.recordId, source.recordId);
      expect(decoded.payload, source.payload);
    },
  );

  test('maps a wallet read failure without publishing empty', () async {
    when(
      () => repository.getAllFrozenWalletOutpoints(),
    ).thenThrow(Exception('database locked with private row details'));

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
      'wallet.utxo_freeze',
    );
  });

  test('validates exact freeze payload, scope, and outpoint identity', () {
    final valid = WalletMetadataRecord(
      type: 'wallet.utxo_freeze',
      version: 1,
      scope: const {'kind': 'wallet', 'walletRef': 'wallet-a'},
      recordId: '$txId:3',
      payload: {
        'walletRef': 'wallet-a',
        'txid': txId,
        'vout': 3,
        'frozen': true,
      },
    );
    final wrongScope = WalletMetadataRecord(
      type: valid.type,
      version: valid.version,
      scope: const {'kind': 'unattributed'},
      recordId: valid.recordId,
      payload: valid.payload,
    );
    final extraPayload = WalletMetadataRecord(
      type: valid.type,
      version: valid.version,
      scope: valid.scope,
      recordId: valid.recordId,
      payload: {...valid.payload, 'spendable': false},
    );

    expect(contributor.validateRecord(valid), isA<WalletMetadataRecordValid>());
    expect(
      (contributor.validateRecord(wrongScope) as WalletMetadataRecordInvalid)
          .reason,
      WalletMetadataRecordInvalidReason.invalidScope,
    );
    expect(
      (contributor.validateRecord(extraPayload) as WalletMetadataRecordInvalid)
          .reason,
      WalletMetadataRecordInvalidReason.invalidPayload,
    );
  });

  test(
    'restores additively without treating an extra local freeze as loss',
    () async {
      final record = WalletMetadataRecord(
        type: 'wallet.utxo_freeze',
        version: 1,
        scope: const {'kind': 'wallet', 'walletRef': 'wallet-a'},
        recordId: '$txId:3',
        payload: {
          'walletRef': 'wallet-a',
          'txid': txId,
          'vout': 3,
          'frozen': true,
        },
      );
      when(() => repository.getAllFrozenWalletOutpoints()).thenAnswer(
        (_) async => [
          FrozenWalletOutpoint(walletId: 'wallet-a', txId: txId, vout: 3),
          FrozenWalletOutpoint(
            walletId: 'wallet-extra',
            txId: 'b' * 64,
            vout: 0,
          ),
        ],
      );
      when(
        () => repository.restoreFrozenWalletOutpoints(any()),
      ).thenAnswer((_) async {});

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

      expect(summary.restoredCount, 0);
      expect(summary.alreadyPresentCount, 1);
      expect(summary.localProjectionMatchesSnapshot, isTrue);
      verify(() => repository.restoreFrozenWalletOutpoints(any())).called(1);
    },
  );
}

List<WalletMetadataRecord> _requireOk(
  Result<List<WalletMetadataRecord>, WalletMetadataBackupFailure> result,
) {
  return switch (result) {
    Ok(:final value) => value,
    Err(:final failure) => throw TestFailure(
      'expected Ok, got ${failure.runtimeType}',
    ),
  };
}
