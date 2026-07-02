import 'package:bb_mobile/core/fees/domain/fees_entity.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/wallet/data/repositories/bitcoin_wallet_repository.dart';
import 'package:bb_mobile/core/wallet/data/repositories/liquid_wallet_repository.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_address_repository.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/features/autosweep/domain/autosweep_error.dart';
import 'package:bb_mobile/features/autosweep/domain/autosweep_wallet_port.dart';

/// Implements the domain wallet port over the concrete core wallet
/// repositories and maps their raw exceptions to the sealed
/// [AutosweepError] family at this boundary.
class AutosweepWalletAdapter implements AutosweepWalletPort {
  final WalletRepository _walletRepository;
  final WalletAddressRepository _walletAddressRepository;
  final LiquidWalletRepository _liquidWalletRepository;
  final BitcoinWalletRepository _bitcoinWalletRepository;

  const AutosweepWalletAdapter({
    required this._walletRepository,
    required this._walletAddressRepository,
    required this._liquidWalletRepository,
    required this._bitcoinWalletRepository,
  });

  @override
  Future<Wallet?> getDefaultWallet({
    required Wallet sourceWallet,
    bool onlyBitcoin = false,
    bool onlyLiquid = false,
  }) {
    return _guard('default wallet lookup', () async {
      final defaultWallets = await _walletRepository.getWallets(
        environment: sourceWallet.isTestnet
            ? Environment.testnet
            : Environment.mainnet,
        onlyDefaults: true,
        onlyBitcoin: onlyBitcoin,
        onlyLiquid: onlyLiquid,
      );
      return defaultWallets.firstOrNull;
    });
  }

  @override
  Future<String> getCurrentReceiveAddress({required String walletId}) {
    return _guard('receive address selection', () async {
      final address = await _walletAddressRepository
          .getLastRevealedReceiveAddress(walletId: walletId);
      return address.address;
    });
  }

  @override
  Future<String> buildLiquidDrainPset({
    required String walletId,
    required String address,
    required NetworkFee networkFee,
  }) {
    return _guard('Liquid drain construction', () {
      return _liquidWalletRepository.buildPset(
        walletId: walletId,
        address: address,
        networkFee: networkFee,
        drain: true,
      );
    });
  }

  @override
  Future<String> signLiquidPset({
    required String pset,
    required String walletId,
  }) {
    return _guard('Liquid drain signing', () {
      return _liquidWalletRepository.signPset(pset: pset, walletId: walletId);
    });
  }

  @override
  Future<String> buildBitcoinDrainPsbt({
    required String walletId,
    required String address,
    required NetworkFee networkFee,
  }) {
    return _guard('Bitcoin drain construction', () {
      return _bitcoinWalletRepository.buildPsbt(
        walletId: walletId,
        address: address,
        networkFee: networkFee,
        drain: true,
      );
    });
  }

  @override
  Future<int> getBitcoinFeeSat({required String psbt}) {
    return _guard('Bitcoin fee calculation', () {
      return _bitcoinWalletRepository.getTxFeeAmount(psbt: psbt);
    });
  }

  @override
  Future<String> signBitcoinPsbt({
    required String psbt,
    required String walletId,
  }) {
    return _guard('Bitcoin drain signing', () {
      return _bitcoinWalletRepository.signPsbt(psbt, walletId: walletId);
    });
  }

  Future<T> _guard<T>(String operation, Future<T> Function() run) async {
    try {
      return await run();
    } catch (e) {
      throw AutosweepWalletOperationException(
        'Autosweep $operation failed: $e',
      );
    }
  }
}
