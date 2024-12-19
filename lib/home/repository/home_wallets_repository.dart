import 'package:bb_mobile/_model/wallet.dart';
import 'package:bb_mobile/_pkg/wallet/repository/storage.dart';

class HomeWalletsRepository {
  HomeWalletsRepository({
    required WalletsStorageRepository walletsStorageRepository,
  }) : _walletsStorageRepository = walletsStorageRepository;

  final WalletsStorageRepository _walletsStorageRepository;
  final List<Wallet> _wallets = <Wallet>[];

  Stream<List<Wallet>> get wallets => Stream.value(_wallets);
  Stream<Wallet> wallet(String id) => Stream.value(
        _wallets.firstWhere((_) => _.id == id),
      );

  Wallet? walletX(String id) {
    return _wallets.firstWhere((_) => _.id == id);
  }

  Future<void> getWalletsFromStorage() async {
    final (wallets, err) = await _walletsStorageRepository.readAllWallets();
    if (err != null && err.toString() != 'No Key') {
      return;
    }

    if (wallets == null) {
      return;
    }

    _wallets.addAll(wallets);
  }

  void updateWallet(Wallet wallet) {
    final idx = _wallets.indexWhere((_) => _.id == wallet.id);
    if (idx == -1) {
      _wallets.add(wallet);
    } else {
      _wallets[idx] = wallet;
    }
  }

  void deleteWallet(String id) {
    _wallets.removeWhere((_) => _.id == id);
  }
}
