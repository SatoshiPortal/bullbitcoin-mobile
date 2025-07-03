import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';

class ImportWatchOnlyXpubUsecase {
  final WalletRepository _wallet;

  ImportWatchOnlyXpubUsecase({required WalletRepository walletRepository})
    : _wallet = walletRepository;

  Future<Wallet> call({
    required String xpub,
    required Network network,
    required ScriptType scriptType,
    String label = '',
  }) async {
    try {
      final wallet = await _wallet.importWatchOnlyXpub(
        xpub: xpub,
        network: network,
        scriptType: scriptType,
        label: label,
      );

      return wallet;
    } catch (e) {
      throw ImportWatchOnlyXpubException(e.toString());
    }
  }
}

class ImportWatchOnlyXpubException implements Exception {
  final String message;

  ImportWatchOnlyXpubException(this.message);
}
