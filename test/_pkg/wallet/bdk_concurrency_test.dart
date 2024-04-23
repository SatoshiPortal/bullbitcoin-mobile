import 'package:bb_mobile/_pkg/wallet/testable_wallets.dart';
import 'package:bdk_flutter/bdk_flutter.dart' as bdk;
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('getAddress waits while syncing wallet', () async {
    final wallet1 = await _createWallet(mne: secureTN1.join(' '));
    final blockchain = await _createBlockchain();
    wallet1.sync(blockchain: blockchain);
    final _ = await wallet1.getAddress(addressIndex: const bdk.AddressIndex.lastUnused());
    print('this message should omes before "sync complete" message or test passed');
  });

  test('getAddress waits for multiple wallets to sync', () async {
    final wallet1 = await _createWallet(mne: secureTN1.join(' '));
    final wallet2 = await _createWallet();
    final blockchain = await _createBlockchain();
    wallet1.sync(blockchain: blockchain);
    wallet2.sync(blockchain: blockchain);
    await wallet1.getAddress(addressIndex: const bdk.AddressIndex.lastUnused());
    // await wallet2.getAddress(addressIndex: const bdk.AddressIndex.lastUnused());
    print('this message should comes before "sync complete" message or test passed');
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
    mnemonic = await bdk.Mnemonic.create(bdk.WordCount.words12);

  final descriptorSecretKey =
      await bdk.DescriptorSecretKey.create(network: bdk.Network.testnet, mnemonic: mnemonic);

  final externalDescriptor = await bdk.Descriptor.newBip44(
    secretKey: descriptorSecretKey,
    network: bdk.Network.testnet,
    keychain: bdk.KeychainKind.externalChain,
  );

  final internalDescriptor = await bdk.Descriptor.newBip44(
    secretKey: descriptorSecretKey,
    network: bdk.Network.testnet,
    keychain: bdk.KeychainKind.internalChain,
  );

  final wallet = await bdk.Wallet.create(
    descriptor: externalDescriptor,
    changeDescriptor: internalDescriptor,
    network: bdk.Network.testnet,
    databaseConfig: const bdk.DatabaseConfig.memory(),
  );

  return wallet;
}
