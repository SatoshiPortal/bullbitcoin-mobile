import 'package:bb_mobile/_model/wallet.dart';
import 'package:bb_mobile/_repository/wallet/wallet_storage.dart';
import 'package:bb_mobile/_repository/wallet_service.dart';

class AppWalletsRepository {
  AppWalletsRepository({
    required WalletsStorageRepository walletsStorageRepository,
  }) : _walletsStorageRepository = walletsStorageRepository;

  final WalletsStorageRepository _walletsStorageRepository;
  final List<Wallet> _wallets = <Wallet>[];
  List<WalletService> _walletServices = [];

  Stream<List<Wallet>> get wallets2 => Stream.value(
        _walletServices.map((_) => _.wallet).toList(),
      );

  Stream<Wallet> wallet2(String id) => Stream.value(
        _walletServices.firstWhere((_) => _.wallet.id == id).wallet,
      );

  WalletService? getWalletServiceById2(String id) {
    final idx = _walletServices.indexWhere((_) => _.wallet.id == id);
    if (idx == -1) return null;
    return _walletServices[idx];
  }

  Wallet? getWalletById2(String id) {
    final idx = _walletServices.indexWhere((_) => _.wallet.id == id);
    if (idx == -1) return null;
    return _walletServices[idx].wallet;
  }

  Future<void> getWalletsFromStorage2() async {
    final (wallets, err) = await _walletsStorageRepository.readAllWallets();
    if (err != null && err.toString() != 'No Key') {
      return;
    }

    if (wallets == null) {
      return;
    }

    _wallets.addAll(wallets);
    _walletServices =
        _wallets.map((_) => createWalletService(wallet: _)).toList();
  }

  void updateWallet2(Wallet wallet) {
    final idx = _walletServices.indexWhere((_) => _.wallet.id == wallet.id);
    if (idx == -1) {
      _walletServices.add(createWalletService(wallet: wallet));
    } else {
      // _walletServices[idx].updateWallet(wallet);
    }
  }

  void deleteWallet2(String id) {
    _walletServices.removeWhere((_) => _.wallet.id == id);
  }

  bool get hasWallets2 => _walletServices.isNotEmpty;
  bool get hasMainWallets2 => _walletServices.any((_) => _.wallet.mainWallet);
  List<Wallet> walletsFromNetwork2(BBNetwork network) => _walletServices
      .map((_) => _.wallet)
      .where((_) => _.network == network)
      .toList();

  Wallet? getMainInstantWallet2(BBNetwork network) {
    final wallets = walletsFromNetwork2(network);
    final idx = wallets.indexWhere(
      (_) => _.isInstant() && _.mainWallet,
    );
    if (idx == -1) return null;
    return wallets[idx];
  }

  Wallet? getMainSecureWallet2(BBNetwork network) {
    final wallets = walletsFromNetwork2(network);
    final idx = wallets.indexWhere(
      (_) => _.isSecure() && _.mainWallet,
    );
    if (idx == -1) return null;
    return wallets[idx];
  }

  // Stream<List<Wallet>> get wallets => Stream.value(_wallets);
  // Stream<Wallet> wallet(String id) => Stream.value(
  //       _wallets.firstWhere((_) => _.id == id),
  //     );

  // Wallet? getWalletById(String id) {
  //   final idx = _wallets.indexWhere((_) => _.id == id);
  //   if (idx == -1) return null;
  //   return _wallets[idx];
  // }

  // Future<void> getWalletsFromStorage() async {
  //   final (wallets, err) = await _walletsStorageRepository.readAllWallets();
  //   if (err != null && err.toString() != 'No Key') {
  //     return;
  //   }

  //   if (wallets == null) {
  //     return;
  //   }

  //   _wallets.addAll(wallets);
  // }

  // void updateWallet(Wallet wallet) {
  //   final idx = _wallets.indexWhere((_) => _.id == wallet.id);
  //   if (idx == -1) {
  //     _wallets.add(wallet);
  //   } else {
  //     _wallets[idx] = wallet;
  //   }
  // }

  // void deleteWallet(String id) {
  //   _wallets.removeWhere((_) => _.id == id);
  // }

  // bool get hasWallets => _wallets.isNotEmpty;
  // bool get hasMainWallets => _wallets.any((_) => _.mainWallet);
  // List<Wallet> walletsFromNetwork(BBNetwork network) =>
  //     _wallets.where((_) => _.network == network).toList();

  // Wallet? getMainInstantWallet(BBNetwork network) {
  //   final wallets = walletsFromNetwork(network);
  //   final idx = wallets.indexWhere(
  //     (_) => _.isInstant() && _.mainWallet,
  //   );
  //   if (idx == -1) return null;
  //   return wallets[idx];
  // }

  // Wallet? getMainSecureWallet(BBNetwork network) {
  //   final wallets = walletsFromNetwork(network);
  //   final idx = wallets.indexWhere(
  //     (_) => _.isSecure() && _.mainWallet,
  //   );
  //   if (idx == -1) return null;
  //   return wallets[idx];
  // }
}
