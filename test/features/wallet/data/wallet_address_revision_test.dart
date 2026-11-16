import 'package:bb_mobile/core/storage/tables/wallet_signer_table.dart';

import '../../../core_test/wallet/wallet_signer_test_fixture.dart';

import 'package:bb_mobile/features/wallet/data/sync_wallet_values_datasource.dart';
import 'package:bb_mobile/features/wallet/data/wallet_metadata_datasource.dart';
import 'package:bb_mobile/features/wallet/data/models/wallet_metadata_model.dart';
import 'package:bb_mobile/features/wallet/data/models/wallet_model.dart';
import 'package:bb_mobile/features/labels/labels_facade.dart';
import 'package:bb_mobile/features/wallet/data/wallet_address_repository.dart';
import 'package:bb_mobile/features/wallet/data/wallet_native_runtime.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _Metadata extends Mock implements WalletMetadataDatasource {}

class _Native extends Mock implements WalletNativeLifecycle {}

class _Values extends Mock implements SyncWalletValuesDatasource {}

class _Labels extends Mock implements LabelsFacade {}

void main() {
  test(
    'Liquid address history includes the writer issued high-water',
    () async {
      const id = 'elwpkh([aabbccdd/84h/1776h/0h])';
      final row = WalletMetadataModel(
        networkCode: 'liquidMainnet',
        id: id,
        isEncryptedVaultTested: false,
        isPhysicalBackupTested: false,
        isDefault: false,
        signers: [
          walletSignerModel(
            id: 'signer-0',
            descriptorKeyId: 'key-0',
            masterFingerprint: 'aabbccdd',
            xpubFingerprint: 'aabbccdd',
            xpub: 'public',
            signer: Signer.none,
            signerDevice: null,
          ),
        ],
        publicDescriptor: ('ct(slip77(public),elwpkh(public))')
            .split('#')
            .first
            .replaceAll('/0/*', '/<0;1>/*'),
      );
      registerFallbackValue(WalletModel.fromMetadata(row));
      final metadata = _Metadata();
      final native = _Native();
      final liquid = _Values();
      final labels = _Labels();
      when(() => metadata.fetch(id)).thenAnswer((_) async => row);
      when(() => native.issuedReceiveIndex(row)).thenAnswer((_) async => 7);
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
      when(() => labels.fetchByReference(any())).thenAnswer((_) async => []);
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
      final next = await repository.getGeneratedReceiveAddresses(
        id,
        limit: 2,
        fromIndex: 4,
      );
      expect(next.map((address) => address.index), [4, 3]);
    },
  );
}
