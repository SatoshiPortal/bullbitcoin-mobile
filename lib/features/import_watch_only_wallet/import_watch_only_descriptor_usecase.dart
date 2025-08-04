import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/features/import_watch_only_wallet/watch_only_wallet_entity.dart';

class ImportWatchOnlyDescriptorUsecase {
  final WalletRepository _wallet;

  ImportWatchOnlyDescriptorUsecase({required WalletRepository walletRepository})
    : _wallet = walletRepository;

  Future<Wallet> call({
    required WatchOnlyDescriptorEntity watchOnlyDescriptor,
  }) async {
    try {
      final wallet = await _wallet.importDescriptor(
        watchOnlyDescriptor: watchOnlyDescriptor,
      );

      return wallet;
    } catch (e) {
      throw ImportWatchOnlyDescriptorException(e.toString());
    }
  }
}

class ImportWatchOnlyDescriptorException implements Exception {
  final String message;

  ImportWatchOnlyDescriptorException(this.message);
}
