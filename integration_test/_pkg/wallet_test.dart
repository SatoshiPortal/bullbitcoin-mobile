import 'package:bb_mobile/_model/wallet.dart';
import 'package:bb_mobile/_pkg/wallet/sensitive/create.dart';
import 'package:bb_mobile/_pkg/wallet/update.dart';
import 'package:test/test.dart';

void main() {
  test('Error in mnemonics recovery', () async {
    const mnemonic = 'chronic pilot sell cigar case clinic produce parent steel radar raw inch';
    const passphrase = '';
    final (wallet, _) = await WalletSensitiveCreate().allFromBIP39(
      mnemonic,
      passphrase,
      BBNetwork.Testnet,
      false,
    );
    final w84 = wallet![2];

    final (w84Updated, _) = await WalletUpdate().syncUpdateWallet(
      wallet: w84,
    );
    print(w84Updated);
  });
}
