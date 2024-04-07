import 'package:bb_mobile/_model/seed.dart';
import 'package:bb_mobile/_model/wallet.dart';
import 'package:bb_mobile/_pkg/error.dart';
import 'package:bb_mobile/_pkg/wallet/_interface.dart';
import 'package:bb_mobile/_pkg/wallet/bdk/sensitive_create.dart';

class WalletSensitiveCreate implements IWalletSensitiveCreate {
  WalletSensitiveCreate({
    required BDKSensitiveCreate bdkSensitiveCreate,
  }) : _bdkSensitiveCreate = bdkSensitiveCreate;

  final BDKSensitiveCreate _bdkSensitiveCreate;

  @override
  Future<(List<String>?, Err?)> createMnemonic() async {
    try {
      return await _bdkSensitiveCreate.createMnemonic();
    } on Exception catch (e) {
      return (
        null,
        Err(
          e.message,
          title: 'Error occurred while creating mnemonic',
          solution: 'Please try again.',
        )
      );
    }
  }

  @override
  Future<(String?, Err?)> getFingerprint({
    required String mnemonic,
    String? passphrase,
  }) async {
    try {
      return await _bdkSensitiveCreate.getFingerprint(mnemonic: mnemonic, passphrase: passphrase);
    } on Exception catch (e) {
      return (
        null,
        Err(
          e.message,
          title: 'Error occurred while creating fingerprint',
          solution: 'Please try again.',
        )
      );
    }
  }

  @override
  Future<(Seed?, Err?)> mnemonicSeed(
    String mnemonic,
    BBNetwork network,
  ) async {
    try {
      final (mnemonicFingerprint, err) = await getFingerprint(
        mnemonic: mnemonic,
        passphrase: '',
      );
      if (err != null) throw err;

      final seed = Seed(
        mnemonic: mnemonic,
        mnemonicFingerprint: mnemonicFingerprint!,
        passphrases: [],
        network: network,
      );
      return (seed, null);
    } catch (e) {
      return (
        null,
        Err(
          e.toString(),
          title: 'Error occurred while creating seed',
          solution: 'Please try again.',
        )
      );
    }
  }
}
