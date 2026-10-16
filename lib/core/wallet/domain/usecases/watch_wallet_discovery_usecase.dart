import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';

class WatchWalletDiscoveryUsecase {
  final WalletRepository _walletRepository;
  const WatchWalletDiscoveryUsecase(this._walletRepository);

  Stream<bool> execute() => _walletRepository.walletDiscoveryStream;
}
