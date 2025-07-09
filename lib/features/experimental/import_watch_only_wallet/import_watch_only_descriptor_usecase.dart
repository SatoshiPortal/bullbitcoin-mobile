import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';

class ImportWatchOnlyDescriptorUsecase {
  final WalletRepository _wallet;

  ImportWatchOnlyDescriptorUsecase({required WalletRepository walletRepository})
    : _wallet = walletRepository;

  Future<Wallet> call({required String descriptor, String label = ''}) async {
    try {
      final wallet = await _wallet.importDescriptor(
        descriptor: descriptor,
        label: label,
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
