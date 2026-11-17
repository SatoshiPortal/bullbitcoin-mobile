import 'package:rust_bindings/bdk.dart' as bdk;
import 'package:primitives/primitives.dart';
import 'package:sync/sync.dart';

// Published BIP39 vector; no application custody material.
BitcoinWalletDescriptor regtestDescriptor({String suffix = ''}) {
  final mnemonic = bdk.Mnemonic.fromString(
    mnemonic:
        'abandon abandon abandon abandon abandon abandon abandon abandon '
        'abandon abandon abandon about',
  );
  final secret = bdk.DescriptorSecretKey(
    networkKind: bdk.NetworkKind.test,
    mnemonic: mnemonic,
    password: null,
  );
  String derive(bdk.KeychainKind keychain) {
    final descriptor = bdk.Descriptor.newBip84(
      secretKey: secret,
      keychainKind: keychain,
      networkKind: bdk.NetworkKind.test,
    );
    try {
      return descriptor.toString();
    } finally {
      descriptor.dispose();
    }
  }

  try {
    return BitcoinWalletDescriptor(
      key: WalletKey(
        id: 'published-vector$suffix:regtest',
        network: BitcoinNetwork.regtest,
      ),
      scriptType: ScriptType.bip84,
      origin: 'wpkh([73c5da0a/84h/1h/0h])',
      externalDescriptor: derive(bdk.KeychainKind.external_),
      internalDescriptor: derive(bdk.KeychainKind.internal),
    );
  } finally {
    secret.dispose();
    mnemonic.dispose();
  }
}

final class SingleWalletCatalog implements WalletCatalogPort {
  final PublicWalletDescriptor descriptor;
  SingleWalletCatalog(this.descriptor);

  @override
  Future<Result<PublicWalletDescriptor, SyncFailure>> find(
    WalletKey key,
  ) async =>
      key == descriptor.key ? Ok(descriptor) : const Err(SyncNotFoundFailure());

  @override
  Future<Result<List<PublicWalletDescriptor>, SyncFailure>> list() async =>
      Ok([descriptor]);
}

final class NoReservedAddresses implements ReservedAddressPort {
  @override
  Future<Result<bool, SyncFailure>> isReserved(
    WalletKey key,
    String address,
  ) async => const Ok(false);
}
