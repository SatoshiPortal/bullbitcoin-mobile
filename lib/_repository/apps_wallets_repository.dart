import 'package:bb_mobile/_model/wallet.dart';
import 'package:bb_mobile/_repository/wallet/wallet_storage.dart';

class AppWalletsRepository {
  AppWalletsRepository({
    required WalletsStorageRepository walletsStorageRepository,
  }) : _walletsStorageRepository = walletsStorageRepository;

  final WalletsStorageRepository _walletsStorageRepository;
  final List<Wallet> _wallets = <Wallet>[];

  Stream<List<Wallet>> get wallets => Stream.value(_wallets);
  Stream<Wallet> wallet(String id) => Stream.value(
        _wallets.firstWhere((_) => _.id == id),
      );
  Wallet? getWalletById(String id) {
    final idx = _wallets.indexWhere((_) => _.id == id);
    if (idx == -1) return null;
    return _wallets[idx];
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

  bool get hasWallets => _wallets.isNotEmpty;
  bool get hasMainWallets => _wallets.any((_) => _.mainWallet);
  List<Wallet> walletsFromNetwork(BBNetwork network) =>
      _wallets.where((_) => _.network == network).toList();

  Wallet? getMainInstantWallet(BBNetwork network) {
    final wallets = walletsFromNetwork(network);
    final idx = wallets.indexWhere(
      (_) => _.isInstant() && _.mainWallet,
    );
    if (idx == -1) return null;
    return wallets[idx];
  }

  Wallet? getMainSecureWallet(BBNetwork network) {
    final wallets = walletsFromNetwork(network);
    final idx = wallets.indexWhere(
      (_) => _.isSecure() && _.mainWallet,
    );
    if (idx == -1) return null;
    return wallets[idx];
  }
}
