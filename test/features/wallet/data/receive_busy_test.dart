import 'package:bb_mobile/core/storage/tables/wallet_metadata_table.dart'
    show Signer;
import 'package:bb_mobile/core/wallet/data/datasources/bdk_wallet_datasource.dart';
import 'package:bb_mobile/core/wallet/data/datasources/lwk_wallet_datasource.dart';
import 'package:bb_mobile/core/wallet/data/datasources/wallet_metadata_datasource.dart';
import 'package:bb_mobile/core/wallet/data/models/wallet_metadata_model.dart';
import 'package:bb_mobile/features/labels/labels_facade.dart';
import 'package:bb_mobile/features/wallet/data/wallet_address_repository.dart';
import 'package:bb_mobile/features/wallet/data/wallet_native_runtime.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:transaction_sync/read.dart';
import 'package:transaction_sync/transaction_sync.dart';

class _Metadata extends Mock implements WalletMetadataDatasource {}

class _Native extends Mock implements WalletNativeLifecycle {}

class _Bitcoin extends Mock implements BdkWalletDatasource {}

class _Liquid extends Mock implements LwkWalletDatasource {}

class _Labels extends Mock implements LabelsFacade {}

void main() {
  for (final origin in [
    'wpkh([aabbccdd/84h/0h/0h])',
    'elwpkh([aabbccdd/84h/1776h/0h])',
  ]) {
    group(origin.startsWith('el') ? 'Liquid' : 'Bitcoin', () {
      late _Native native;
      late _Labels labels;
      late WalletAddressRepository repository;
      final row = WalletMetadataModel(
        id: origin,
        masterFingerprint: 'aabbccdd',
        xpubFingerprint: 'aabbccdd',
        isEncryptedVaultTested: false,
        isPhysicalBackupTested: false,
        xpub: 'public',
        externalPublicDescriptor: 'public',
        internalPublicDescriptor: '',
        signer: Signer.none,
        isDefault: false,
      );
      setUp(() {
        native = _Native();
        labels = _Labels();
        final metadata = _Metadata();
        when(() => metadata.fetch(origin)).thenAnswer((_) async => row);
        when(() => labels.fetchByReference(any())).thenAnswer((_) async => []);
        repository = WalletAddressRepository(
          native: native,
          walletMetadataDatasource: metadata,
          bdkWalletDatasource: _Bitcoin(),
          lwkWalletDatasource: _Liquid(),
          labelsFacade: labels,
        );
      });

      test(
        'receive waits for a busy writer then returns the issued address',
        () async {
          var attempts = 0;
          when(() => native.receive(row, advance: false)).thenAnswer((_) async {
            if (++attempts < 3) {
              throw const WalletSnapshotException(TransactionSyncBusyFailure());
            }
            return (address: 'issued', index: 7);
          });
          final address = await repository.getLastRevealedReceiveAddress(
            walletId: origin,
          );
          expect(address.address, 'issued');
          expect(address.index, 7);
          expect(attempts, 3);
        },
      );

      test('persistent busy is bounded', () async {
        when(() => native.receive(row, advance: false)).thenThrow(
          const WalletSnapshotException(TransactionSyncBusyFailure()),
        );
        await expectLater(
          repository.getLastRevealedReceiveAddress(walletId: origin),
          throwsA(
            isA<WalletSnapshotException>().having(
              (e) => e.failure,
              'failure',
              isA<TransactionSyncBusyFailure>(),
            ),
          ),
        );
        verify(() => native.receive(row, advance: false)).called(5);
        verifyNever(() => labels.fetchByReference(any()));
      });

      test('other failures are not retried', () async {
        const error = WalletSnapshotException(
          TransactionSyncNeedsRepairFailure(),
        );
        when(() => native.receive(row, advance: false)).thenThrow(error);
        await expectLater(
          repository.getLastRevealedReceiveAddress(walletId: origin),
          throwsA(same(error)),
        );
        verify(() => native.receive(row, advance: false)).called(1);
      });

      test('label failure after issuance never replays an advance', () async {
        when(
          () => native.receive(row, advance: true),
        ).thenAnswer((_) async => (address: 'issued', index: 8));
        const error = WalletSnapshotException(TransactionSyncBusyFailure());
        when(() => labels.fetchByReference(any())).thenThrow(error);
        await expectLater(
          repository.generateNewReceiveAddress(walletId: origin),
          throwsA(same(error)),
        );
        verify(() => native.receive(row, advance: true)).called(1);
      });
    });
  }
}
