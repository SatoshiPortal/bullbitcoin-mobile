import 'package:bb_mobile/_model/swap.dart';
import 'package:bb_mobile/_model/transaction.dart';
import 'package:bb_mobile/_model/wallet.dart';
import 'package:bb_mobile/_repository/wallet/wallet_storage.dart';
import 'package:bb_mobile/_repository/wallet_service.dart';

class AppWalletsRepository {
  AppWalletsRepository({
    required WalletsStorageRepository walletsStorageRepository,
  }) : _walletsStorageRepository = walletsStorageRepository;
  final WalletsStorageRepository _walletsStorageRepository;

  final List<WalletService> _walletServices = [];

  Future<void> getWalletsFromStorage() async {
    final (wallets, err) = await _walletsStorageRepository.readAllWallets();
    if (err != null && err.toString() != 'No Key') {
      return;
    }

    if (wallets == null) {
      return;
    }

    _walletServices.clear();
    _walletServices.addAll(
      wallets
          .map((_) => createWalletService(wallet: _, fromStorage: true))
          .toList(),
    );
  }

  List<Wallet> get allWallets => _walletServices.map((_) => _.wallet).toList();

  Wallet? getWalletById(String id) {
    final idx = _walletServices.indexWhere((_) => _.wallet.id == id);
    if (idx == -1) return null;
    return _walletServices[idx].wallet;
  }

  WalletService? getWalletServiceById(String id) {
    final idx = _walletServices.indexWhere((_) => _.wallet.id == id);
    if (idx == -1) return null;
    return _walletServices[idx];
  }

  void deleteWallet(String id) {
    _walletServices.removeWhere((_) => _.wallet.id == id);
  }

  List<WalletService> walletServiceFromNetwork(BBNetwork network) =>
      _walletServices.where((_) => _.wallet.network == network).toList();

  Future loadAllInNetwork(BBNetwork network) async {
    final ws = walletServiceFromNetwork(network);
    await Future.wait(
      ws.map((w) => w.loadWallet()),
    );
  }

  Future syncAllInNetwork(BBNetwork network) async {
    final ws = walletServiceFromNetwork(network);
    for (final w in ws) {
      w.syncWallet();
    }
  }

  bool get hasWallets => _walletServices.isNotEmpty;
  bool get hasMainWallets => _walletServices.any((_) => _.wallet.mainWallet);
  List<Wallet> walletsFromNetwork(BBNetwork network) => _walletServices
      .map((_) => _.wallet)
      .where((_) => _.network == network)
      .toList();

  Wallet getColdCardWallet(BBNetwork network) {
    return walletsFromNetwork(network)
        .where(
          (_) => _.network == network && _.type == BBWalletType.coldcard,
        )
        .first;
  }

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

  WalletService? getMainSecureWalletService(BBNetwork network) {
    final wallet = getMainSecureWallet(network);
    if (wallet == null) return null;
    return getWalletServiceById(wallet.id);
  }

  WalletService? getMainInstantWalletService(BBNetwork network) {
    final wallet = getMainInstantWallet(network);
    if (wallet == null) return null;
    return getWalletServiceById(wallet.id);
  }

  List<WalletService> getMainWalletServices(bool isTestnet) {
    final network = isTestnet ? BBNetwork.Testnet : BBNetwork.Mainnet;
    final instantwallet = getMainInstantWalletService(network);
    final securewallet = getMainSecureWalletService(network);
    return [
      if (instantwallet != null) instantwallet,
      if (securewallet != null) securewallet,
    ];
  }

  List<Wallet> getMainWallets(bool isTestnet) {
    final network = isTestnet ? BBNetwork.Testnet : BBNetwork.Mainnet;
    final instantwallet = getMainInstantWallet(network);
    final securewallet = getMainSecureWallet(network);
    return [
      if (instantwallet != null) instantwallet,
      if (securewallet != null) securewallet,
    ];
  }

  Transaction? getTxFromSwap(SwapTx swap) {
    final isLiq = swap.isLiquid();
    final network = swap.network;
    final wallet =
        !isLiq ? getMainSecureWallet(network) : getMainInstantWallet(network);
    if (wallet == null) return null;
    final idx = wallet.transactions.indexWhere((t) => t.swapTx?.id == swap.id);
    if (idx == -1) return null;
    return wallet.transactions[idx];
  }

  WalletService? findWalletServiceWithSameFngr(Wallet wallet) {
    for (final ws in _walletServices) {
      final w = ws.wallet;
      if (w.id == wallet.id) continue;
      if (w.sourceFingerprint == wallet.sourceFingerprint) return ws;
    }
    return null;
  }

  List<Wallet> walletsWithEnoughBalance(
    int sats,
    BBNetwork network, {
    bool onlyMain = false,
    bool onlyBitcoin = false,
    bool onlyLiquid = false,
  }) {
    final wallets = walletsFromNetwork(network).where(
      (_) {
        final wallet = _;
        if (onlyMain && !wallet.mainWallet) return false;
        if (onlyBitcoin && !wallet.isBitcoin()) return false;
        if (onlyLiquid && !wallet.isLiquid()) return false;
        return true;
      },
    ).toList();

    final List<Wallet> walletsWithEnoughBalance = [];

    for (final walletBloc in wallets) {
      final enoughBalance = (walletBloc.balance ?? 0) >= sats;
      if (enoughBalance) walletsWithEnoughBalance.add(walletBloc);
    }
    return walletsWithEnoughBalance.isEmpty
        ? wallets
        : walletsWithEnoughBalance;
  }

  List<Wallet> walletNotMainFromNetwork(BBNetwork network) {
    final wallets = walletsFromNetwork(network)
        .where(
          (_) => _.network == network && !_.mainWallet,
        )
        .toList()
        .reversed
        .toList();

    return wallets;
  }

  Wallet? getWalletFromTx(Transaction tx) {
    if (allWallets.isEmpty) return null;

    for (final wallet in allWallets) {
      if (wallet.transactions.indexWhere((t) => t.txid == tx.txid) != -1) {
        return wallet;
      }
    }

    return null;
  }

  List<Wallet> walletFromNetworkExcludeWatchOnly(BBNetwork network) {
    final blocs = allWallets
        .where(
          (_) => _.network == network && _.watchOnly() == false,
        )
        .toList();

    return blocs;
  }
}
