import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/send/data/models/pending_bitcoin_transaction_model.dart';
import 'package:bb_mobile/features/send/data/pending_bitcoin_transaction_datasource.dart';
import 'package:bb_mobile/features/send/data/pending_bitcoin_transaction_repository_impl.dart';
import 'package:bb_mobile/features/send/domain/pending_bitcoin_transaction.dart';
import 'package:bb_mobile/features/send/domain/send_failure.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:bb_mobile/core/storage/sqlite_database.dart';
import 'package:bb_mobile/core/fees/domain/fees_entity.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:drift/native.dart';

class _MockPendingBitcoinTransactionDatasource extends Mock
    implements PendingBitcoinTransactionDatasource {}

void main() {
  test('only valid Bitcoin recipients replace a saved draft', () async {
    final database = SqliteDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    await database
        .into(database.walletMetadatas)
        .insert(
          WalletMetadatasCompanion.insert(
            id: 'wallet-id',
            network: Network.bitcoinMainnet,
            isEncryptedVaultTested: false,
            isPhysicalBackupTested: false,
            publicDescriptor: 'wpkh(xpub/<0;1>/*)',
            isDefault: false,
          ),
        );
    final datasource = PendingBitcoinTransactionDatasource(database);
    final repository = PendingBitcoinTransactionRepositoryImpl(datasource);
    const address = '1BoatSLRHtKNngkdXEeobR76b53LETtpyT';
    final draft = PendingBitcoinTransaction(
      id: 'draft',
      walletId: 'wallet-id',
      stage: PendingBitcoinTransactionStage.draft,
      recipient: address,
      amount: '',
      amountCurrencyCode: 'sats',
      sendMax: false,
      feeSelection: FeeSelection.fastest,
      replaceByFee: true,
      createdAt: DateTime.utc(2026),
      updatedAt: DateTime.utc(2026),
    );
    expect(await repository.save(draft), isA<Ok>());
    for (final invalid in ['', 'bc1qincomplete', 'unrelated clipboard text']) {
      expect(
        await repository.save(
          draft.copyWith(recipient: invalid),
          expectedRevision: 0,
        ),
        isA<Err<PendingBitcoinTransaction, SendFailure>>().having(
          (result) => result.failure,
          'failure',
          isA<SendInvalidPaymentRequestFailure>(),
        ),
      );
      expect((await datasource.get('draft'))!.recipient, address);
    }
    final bip21 = 'bitcoin:$address?amount=0.001';
    expect(
      await repository.save(
        draft.copyWith(recipient: bip21),
        expectedRevision: 0,
      ),
      isA<Ok>(),
    );
    expect((await datasource.get('draft'))!.recipient, bip21);
  });
  test('maps an invalid stored policy selection to a typed failure', () async {
    final datasource = _MockPendingBitcoinTransactionDatasource();
    when(() => datasource.get('pending-id')).thenAnswer(
      (_) async => PendingBitcoinTransactionModel(
        id: 'pending-id',
        walletId: 'wallet-id',
        stage: 'needsSignatures',
        recipient: 'tb1qrecipient',
        amount: '50000',
        amountCurrencyCode: 'sats',
        sendMax: false,
        feeSelection: 'fastest',
        replaceByFee: true,
        selectedOutpoints: const {},
        policyChoices: const {
          'external:root': [-1],
        },
        psbt: 'cHNidP8=',
        createdAt: DateTime.utc(2026, 8, 14),
        updatedAt: DateTime.utc(2026, 8, 14),
      ),
    );

    final result = await PendingBitcoinTransactionRepositoryImpl(
      datasource,
    ).get('pending-id');

    expect(result, isA<Err<PendingBitcoinTransaction?, SendFailure>>());
    expect(
      (result as Err<PendingBitcoinTransaction?, SendFailure>).failure,
      isA<SendStoredTransactionInvalidFailure>(),
    );
  });

  test(
    'maps malformed custom fee storage to an invalid-record failure',
    () async {
      final datasource = _MockPendingBitcoinTransactionDatasource();
      when(() => datasource.get('pending-id')).thenAnswer(
        (_) async => PendingBitcoinTransactionModel(
          id: 'pending-id',
          walletId: 'wallet-id',
          stage: 'draft',
          recipient: '',
          amount: '',
          amountCurrencyCode: '',
          sendMax: false,
          feeSelection: 'custom',
          customFeeKind: 'unknown',
          customFeeValue: 1,
          replaceByFee: true,
          selectedOutpoints: const {},
          policyChoices: const {},
          createdAt: DateTime.utc(2026, 8, 14),
          updatedAt: DateTime.utc(2026, 8, 14),
        ),
      );

      final result = await PendingBitcoinTransactionRepositoryImpl(
        datasource,
      ).get('pending-id');

      expect(result, isA<Err<PendingBitcoinTransaction?, SendFailure>>());
      expect(
        (result as Err<PendingBitcoinTransaction?, SendFailure>).failure,
        isA<SendStoredTransactionInvalidFailure>(),
      );
    },
  );
}
