import 'package:bb_mobile/features/wallet/data/wallet_catalog_port_impl.dart';
import 'package:primitives/primitives.dart';
import 'package:bb_mobile/core/storage/tables/wallet_metadata_table.dart'
    show Signer;
import 'package:bb_mobile/features/wallet/data/sync_wallet_values_datasource.dart';
import 'package:bb_mobile/features/wallet/data/wallet_metadata_datasource.dart';
import 'package:bb_mobile/features/wallet/data/models/wallet_metadata_model.dart';
import 'package:bb_mobile/features/wallet/data/models/wallet_model.dart';
import 'package:labels/labels.dart';
import 'package:bb_mobile/features/wallet/data/wallet_address_repository.dart';
import 'package:sync/write.dart' show WalletNativeLifecycle;
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _Metadata extends Mock implements WalletMetadataDatasource {}

class _Native extends Mock implements WalletNativeLifecycle {}

class _Values extends Mock implements SyncWalletValuesDatasource {}

class _Labels extends Mock implements Labels {}

void main() {
  test(
    'Liquid address history keeps the issued high-water when labels fail',
    () async {
      const id = 'elwpkh([aabbccdd/84h/1776h/0h])';
      final row = WalletMetadataModel(
        networkCode: 'liquidMainnet',
        id: id,
        masterFingerprint: 'aabbccdd',
        xpubFingerprint: 'aabbccdd',
        isEncryptedVaultTested: false,
        isPhysicalBackupTested: false,
        xpub: 'public',
        externalPublicDescriptor: 'ct(slip77(public),elwpkh(public))',
        internalPublicDescriptor: '',
        signer: Signer.none,
        isDefault: false,
      );
      registerFallbackValue(WalletModel.fromMetadata(row));
      final metadata = _Metadata();
      final native = _Native();
      final liquid = _Values();
      final labels = _Labels();
      when(() => metadata.fetch(id)).thenAnswer((_) async => row);
      when(
        () => native.issuedReceiveIndex(
          WalletCatalogPortImpl.keyFromMetadata(row),
        ),
      ).thenAnswer((_) async => const Ok(7));
      when(() => liquid.getLastAddressIndex(wallet: any(named: 'wallet')))
          .thenAnswer((_) async => 0);
      when(
        () => liquid.getAddressByIndex(
          any(),
          wallet: any(named: 'wallet'),
          isChange: any(named: 'isChange'),
        ),
      ).thenAnswer((call) async {
        final index = call.positionalArguments.first as int;
        return 'confidential$index';
      });
      when(() => liquid.getTransactions(wallet: any(named: 'wallet')))
          .thenAnswer((_) async => []);
      when(() => liquid.getAddressBalancesSat(wallet: any(named: 'wallet')))
          .thenAnswer((_) async => {});
      when(() => labels.fetch(reference: any(named: 'reference')))
          .thenAnswer((_) async => const Err(LabelUnexpectedFailure()));
      final repository = WalletAddressRepository(
        native: native,
        walletMetadataDatasource: metadata,
        walletValuesDatasource: liquid,
        labelsFacade: labels,
      );
      final addresses = await repository.getGeneratedReceiveAddresses(
        id,
        limit: 3,
      );
      expect(addresses.map((address) => address.index), [7, 6, 5]);
      expect(addresses.expand((address) => address.labels), isEmpty);
      final next = await repository.getGeneratedReceiveAddresses(
        id,
        limit: 2,
        fromIndex: 4,
      );
      expect(next.map((address) => address.index), [4, 3]);
    },
  );
}
