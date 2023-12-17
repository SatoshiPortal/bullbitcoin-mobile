import 'package:bb_mobile/_pkg/wallet/testable_wallets.dart';
import 'package:bdk_flutter/bdk_flutter.dart' as bdk;
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('getAddress waits while syncing wallet', () async {
    final wallet1 = await _createWallet(mne: r2.join(' '));
    final blockchain = await _createBlockchain();
    wallet1.sync(blockchain);
    final _ = await wallet1.getAddress(addressIndex: const bdk.AddressIndex.lastUnused());
    print('if this message comes before "sync complete" messages test passed');
  });
}

Future<bdk.Blockchain> _createBlockchain() async {
  final blockchain = await bdk.Blockchain.create(
    config: const bdk.BlockchainConfig.electrum(
      config: bdk.ElectrumConfig(
        validateDomain: true,
        stopGap: 10,
        timeout: 5,
        retry: 5,
        url: 'ssl://electrum.blockstream.info:60002',
      ),
    ),
  );
  return blockchain;
}

Future<bdk.Wallet> _createWallet({String? mne}) async {
  late bdk.Mnemonic mnemonic;

  if (mne != null)
    mnemonic = await bdk.Mnemonic.fromString(mne);
  else
    mnemonic = await bdk.Mnemonic.create(bdk.WordCount.Words12);

  final descriptorSecretKey =
      await bdk.DescriptorSecretKey.create(network: bdk.Network.Testnet, mnemonic: mnemonic);

  final externalDescriptor = await bdk.Descriptor.newBip44(
    secretKey: descriptorSecretKey,
    network: bdk.Network.Testnet,
    keychain: bdk.KeychainKind.External,
  );

  final internalDescriptor = await bdk.Descriptor.newBip44(
    secretKey: descriptorSecretKey,
    network: bdk.Network.Testnet,
    keychain: bdk.KeychainKind.Internal,
  );

  final wallet = await bdk.Wallet.create(
    descriptor: externalDescriptor,
    changeDescriptor: internalDescriptor,
    network: bdk.Network.Testnet,
    databaseConfig: const bdk.DatabaseConfig.memory(),
  );

  return wallet;
}
