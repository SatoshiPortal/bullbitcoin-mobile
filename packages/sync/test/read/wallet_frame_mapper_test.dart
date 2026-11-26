import 'package:rust_bindings/bdk.dart' as bdk;
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';
import 'package:sync/src/data/read/wallet_frame_mapper.dart';
import 'package:sync/sync.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('a Bitcoin frame covers revealed addresses and the lookahead', () {
    // Published BIP39 test vector; no application key material.
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
    final external = bdk.Descriptor.newBip84(
      secretKey: secret,
      keychainKind: bdk.KeychainKind.external_,
      networkKind: bdk.NetworkKind.test,
    );
    final internal = bdk.Descriptor.newBip84(
      secretKey: secret,
      keychainKind: bdk.KeychainKind.internal,
      networkKind: bdk.NetworkKind.test,
    );
    final persister = bdk.Persister.newInMemory();
    final wallet = bdk.Wallet(
      descriptor: external,
      changeDescriptor: internal,
      network: bdk.Network.testnet,
      persister: persister,
      lookahead: bitcoinLookahead,
    );
    addTearDown(() {
      wallet.dispose();
      persister.dispose();
      external.dispose();
      internal.dispose();
      secret.dispose();
      mnemonic.dispose();
    });
    for (final info in wallet.revealAddressesTo(
      keychain: bdk.KeychainKind.external_,
      index: 2,
    )) {
      info.address.dispose();
    }
    final key = WalletKey(id: 'mapper', network: BitcoinNetwork.testnet);
    final revision = WalletRevision(key: key, generation: 0, revision: 3);

    final frame = bitcoinFrameData(wallet, revision);

    expect(frame.revision, revision);
    expect(frame.balances.totalSat, BigInt.zero);
    expect(frame.coins, isEmpty);
    expect(frame.transactions, isEmpty);
    expect(frame.addresses.receiveIndex, 2);
    expect(frame.addresses.changeIndex, -1);
    // BIP84 testnet vector, first receive address.
    expect(
      frame.addresses.receive.first.address,
      'tb1q6rz28mcfaxtmd6v789l9rrlrusdprr9pqcpvkl',
    );
    final index = frame.ownership;
    expect(index, isNotNull);
    if (index == null) return;
    bool owns(bdk.KeychainKind keychain, int i) {
      final info = wallet.peekAddress(keychain: keychain, index: i);
      try {
        return index.ownsScript(info.address.scriptPubkey().toBytes());
      } finally {
        info.address.dispose();
      }
    }

    // Revealed scripts and the lookahead beyond them, on both keychains.
    expect(owns(bdk.KeychainKind.external_, 2), isTrue);
    expect(owns(bdk.KeychainKind.external_, 2 + bitcoinLookahead), isTrue);
    expect(owns(bdk.KeychainKind.internal, bitcoinLookahead - 1), isTrue);
    expect(owns(bdk.KeychainKind.external_, 3 + bitcoinLookahead), isFalse);
  });
}
