import 'package:bb_mobile/features/wallet/data/wallet_sync_binding.dart';
import 'package:primitives/primitives.dart';
import 'package:bb_mobile/core/storage/tables/wallet_metadata_table.dart'
    show Signer;
import 'package:bb_mobile/features/wallet/data/wallet_registrations.dart';
import 'package:bb_mobile/features/wallet/data/models/wallet_metadata_model.dart';
import 'package:labels/labels.dart';
import 'package:bb_mobile/features/address_view/data/wallet_address_repository_impl.dart';
import 'package:sync/sync.dart' show AddressBook, Keychain, DerivedAddress;
import 'package:sync/testing.dart' show testWallet;
import 'package:sync/write.dart' show WalletNativeLifecycle;
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _Metadata extends Mock implements WalletRegistrations {}

class _Native extends Mock implements WalletNativeLifecycle {}

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
      final key = WalletSyncBinding.keyFromMetadata(row);
      final metadata = _Metadata();
      final native = _Native();
      final labels = _Labels();
      when(() => metadata.fetch(id)).thenAnswer((_) async => row);
      when(
        () => native.issuedReceiveIndex(WalletSyncBinding.keyFromMetadata(row)),
      ).thenAnswer((_) async => const Ok(7));
      final wallet = await testWallet(
        key: key,
        addresses: AddressBook(
          receiveIndex: 0,
          changeIndex: null,
          receive: [
            for (var index = 0; index <= 7; index++)
              DerivedAddress(
                keychain: Keychain.external,
                index: index,
                address: 'confidential$index',
              ),
          ],
          change: [],
        ),
      );
      when(() => labels.fetch(reference: any(named: 'reference')))
          .thenAnswer((_) async => const Err(LabelUnexpectedFailure()));
      final repository = WalletAddressRepositoryImpl(
        native: native,
        walletRegistrations: metadata,
        loadWallet: (_) async => Ok(wallet),
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
