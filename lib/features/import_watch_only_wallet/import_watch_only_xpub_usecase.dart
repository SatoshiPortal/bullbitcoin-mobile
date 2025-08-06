import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/features/import_watch_only_wallet/watch_only_wallet_entity.dart';

class ImportWatchOnlyXpubUsecase {
  final WalletRepository _wallet;

  ImportWatchOnlyXpubUsecase({required WalletRepository walletRepository})
    : _wallet = walletRepository;

  Future<Wallet> call({required WatchOnlyXpubEntity watchOnlyXpub}) async {
    try {
      final wallet = await _wallet.importWatchOnlyXpub(
        xpub: watchOnlyXpub.pubkey,
        network: watchOnlyXpub.network,
        scriptType: watchOnlyXpub.scriptType,
        label: watchOnlyXpub.label,
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
