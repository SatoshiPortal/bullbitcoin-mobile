import 'package:bb_mobile/_model/wallet.dart';
import 'package:bb_mobile/_pkg/wallet/address.dart';
import 'package:bb_mobile/_pkg/wallet/create.dart';
import 'package:bb_mobile/_pkg/wallet/sensitive/create.dart';
import 'package:bb_mobile/_pkg/wallet/sync.dart';
import 'package:bb_mobile/_pkg/wallet/update.dart';
import 'package:test/test.dart';

void main() {
  test('Error in mnemonics recovery', () async {
    const mnemonic =
        'bitter raccoon quantum sort hollow online toast anxiety student camp learn marriage';
    const passphrase = '';
    final (wallet, _) = await WalletSensitiveCreate().allFromBIP39(
      mnemonic,
      passphrase,
      BBNetwork.Testnet,
      false,
    );
    final w84 = wallet![2];
    final (electrum, _) = await WalletCreate().createBlockChain(
      stopGap: 20,
      timeout: 10,
      retry: 10,
      url: 'ssl://electrum.bullbitcoin.com:60002',
      validateDomain: true,
    );
    final (bdkW84, _) = await WalletCreate().loadPublicBdkWallet(w84);

    await WalletSync().syncWallet(
      bdkWallet: bdkW84!,
      blockChain: electrum!,
    );

    final (w, _) = await WalletAddress().loadNewAddresses(
      wallet: w84,
      bdkWallet: bdkW84,
    );
    print(w!.addresses);

    final (w84Updated, _) = await WalletUpdate().syncWalletTxsAndAddresses(
      wallet: w84,
      bdkWallet: bdkW84,
    );

    assert(w84Updated!.transactions.isNotEmpty);
    // for (final tx in w84Updated!.transactions) {
    // print(tx.);
    // }
  });
}
