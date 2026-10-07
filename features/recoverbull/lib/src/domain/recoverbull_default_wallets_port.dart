import 'entities/recoverbull_wallet.dart';

abstract interface class RecoverBullDefaultWalletsPort {
  Future<List<RecoverBullWallet>> execute({
    required List<String> mnemonicWords,
  });
}
