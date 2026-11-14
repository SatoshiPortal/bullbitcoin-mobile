import 'package:bb_mobile/core/entities/signer_entity.dart';
import 'package:bb_mobile/core/storage/tables/wallet_metadata_table.dart';
import 'package:bb_mobile/features/wallet/data/models/wallet_metadata_model.dart';
import 'package:bb_mobile/features/wallet/data/wallet_catalog_port_impl.dart';
import 'package:bb_mobile/features/wallet/data/wallet_metadata_service.dart';
import 'package:bb_mobile/features/wallet/data/wallet_network_codec.dart';
import 'package:bb_mobile/features/wallet/domain/wallet.dart' as app;
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';
import 'package:sync/sync.dart';

WalletMetadataModel _row(String id, String code) => WalletMetadataModel(
  id: id,
  networkCode: code,
  masterFingerprint: 'aabbccdd',
  xpubFingerprint: 'aabbccdd',
  isEncryptedVaultTested: false,
  isPhysicalBackupTested: false,
  xpub: 'public',
  externalPublicDescriptor: 'wpkh(public)',
  internalPublicDescriptor: 'wpkh(change)',
  signer: Signer.none,
  isDefault: false,
);

void main() {
  for (final network in app.Network.values) {
    test('wallet entity preserves the stored identity on ${network.name}', () {
      final origin = WalletMetadataService.encodeOrigin(
        fingerprint: 'aabbccdd',
        network: network,
        scriptType: app.ScriptType.bip84,
      );
      final wallet = app.Wallet(
        origin: origin,
        network: network,
        xpubFingerprint: 'aabbccdd',
        scriptType: app.ScriptType.bip84,
        xpub: 'public',
        externalPublicDescriptor: 'public-receive',
        internalPublicDescriptor: 'public-change',
        signer: SignerEntity.none,
        signerDevice: null,
        balanceSat: null,
      );
      expect(wallet.origin, origin);
      expect(
        wallet.id,
        WalletMetadataService.encodeId(
          fingerprint: 'aabbccdd',
          network: network,
          scriptType: app.ScriptType.bip84,
        ),
      );
    });
  }
  test('BIP329 origin projection does not select a concrete network', () {
    expect(
      WalletMetadataService.canonicalBip329Origin('[abcd1234/84h/1h/0h]'),
      'wpkh([abcd1234/84h/1h/0h])',
    );
    expect(
      WalletMetadataService.canonicalBip329Origin('[abcd1234/49h/1776h/0h]'),
      'elsh(wpkh([abcd1234/49h/1776h/0h]))',
    );
    expect(
      () => WalletMetadataService.canonicalBip329Origin('[abcd1234/84h/2h/0h]'),
      throwsFormatException,
    );
  });

  const origin = 'wpkh([aabbccdd/84h/1h/0h])';
  test(
    'regtest has a distinct id and the same unsuffixed derivation origin',
    () {
      final id = WalletMetadataService.encodeId(
        fingerprint: 'aabbccdd',
        network: app.Network.bitcoinRegtest,
        scriptType: app.ScriptType.bip84,
      );
      expect(id, '$origin:regtest');
      expect(WalletMetadataService.originFromId(id), origin);
      expect(
        WalletMetadataService.encodeId(
          fingerprint: 'aabbccdd',
          network: app.Network.bitcoinTestnet,
          scriptType: app.ScriptType.bip84,
        ),
        origin,
      );
      final result = WalletCatalogPortImpl.descriptorFromMetadata(
        _row(id, 'bitcoinRegtest'),
      );
      expect(result, isA<Ok<PublicWalletDescriptor, TransactionSyncFailure>>());
      final descriptor =
          (result as Ok<PublicWalletDescriptor, TransactionSyncFailure>).value;
      expect(descriptor.key.network, BitcoinNetwork.regtest);
      expect(descriptor.origin, origin);
    },
  );
  test(
    'catalog rejects unresolved networks and unsuffixed regtest identities',
    () {
      for (final row in [
        _row(origin, 'bitcoinRegtest'),
        _row(origin, 'unresolved'),
        _row('$origin:regtest', 'bitcoinTestnet'),
      ]) {
        expect(
          WalletCatalogPortImpl.descriptorFromMetadata(row),
          isA<Err<PublicWalletDescriptor, TransactionSyncFailure>>(),
        );
        // A row remains usable for cross-network custody reference checks.
        expect(row.seedFingerprint?.hex, 'aabbccdd');
      }
    },
  );
  test(
    'stable text codec round trips all six networks and refuses unknown data',
    () {
      for (final network in app.Network.values) {
        expect(
          WalletNetworkCodec.decode(WalletNetworkCodec.encode(network)),
          network,
        );
      }
      expect(() => WalletNetworkCodec.decode('0'), throwsFormatException);
    },
  );
}
