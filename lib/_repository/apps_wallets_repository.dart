import 'package:bb_mobile/_model/wallet.dart';
import 'package:bb_mobile/_repository/wallet/wallet_storage.dart';
import 'package:bb_mobile/_repository/wallet_service.dart';

class AppWalletsRepository {
  AppWalletsRepository({
    required WalletsStorageRepository walletsStorageRepository,
  }) : _walletsStorageRepository = walletsStorageRepository;

  List<WalletService> _walletServices = [];

  final WalletsStorageRepository _walletsStorageRepository;

  Stream<List<Wallet>> get wallets => Stream.value(
        _walletServices.map((_) => _.wallet).toList(),
      );

  Stream<Wallet> wallet(String id) => Stream.value(
        _walletServices.firstWhere((_) => _.wallet.id == id).wallet,
      );

  WalletService? getWalletServiceById(String id) {
    final idx = _walletServices.indexWhere((_) => _.wallet.id == id);
    if (idx == -1) return null;
    return _walletServices[idx];
  }

  Wallet? getWalletById(String id) {
    final idx = _walletServices.indexWhere((_) => _.wallet.id == id);
    if (idx == -1) return null;
    return _walletServices[idx].wallet;
  }

  Future<void> getWalletsFromStorage() async {
    final (wallets, err) = await _walletsStorageRepository.readAllWallets();
    if (err != null && err.toString() != 'No Key') {
      return;
    }

    if (wallets == null) {
      return;
    }

    _walletServices =
        wallets.map((_) => createWalletService(wallet: _)).toList();
  }

  void updateWallet(Wallet wallet) {
    final idx = _walletServices.indexWhere((_) => _.wallet.id == wallet.id);
    if (idx == -1) {
      _walletServices.add(createWalletService(wallet: wallet));
    } else {
      // _walletServices[idx].updateWallet(wallet);
    }
  }

  void deleteWallet(String id) {
    _walletServices.removeWhere((_) => _.wallet.id == id);
  }

  List<WalletService> walletServiceFromNetwork(BBNetwork network) =>
      _walletServices.where((_) => _.wallet.network == network).toList();

  bool get hasWallets => _walletServices.isNotEmpty;
  bool get hasMainWallets => _walletServices.any((_) => _.wallet.mainWallet);
  List<Wallet> walletsFromNetwork(BBNetwork network) => _walletServices
      .map((_) => _.wallet)
      .where((_) => _.network == network)
      .toList();

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
