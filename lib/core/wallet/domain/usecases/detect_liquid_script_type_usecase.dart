import 'package:bb_mobile/core/seed/domain/entity/seed.dart';
import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';

/// Detects the appropriate script type for a Liquid wallet during recovery.
///
/// This usecase checks if the user has legacy BIP49 (Aqua wallet) funds by:
/// 1. Creating a temporary BIP49 Liquid wallet
/// 2. Syncing it to check on-chain balance
/// 3. Deleting the temporary wallet
/// 4. Returning BIP49 if funds found, otherwise BIP84
///
/// NOTE: We must create a temporary wallet because lwk-dart requires disk-based
/// wallets (no in-memory option like BDK) and doesn't support address derivation
/// without wallet creation. This is a one-time cost during wallet recovery for
/// Aqua compatibility.
class DetectLiquidScriptTypeUsecase {
  final WalletRepository _walletRepository;

  DetectLiquidScriptTypeUsecase({
    required WalletRepository walletRepository,
  }) : _walletRepository = walletRepository;

  Future<ScriptType> execute({
    required Seed seed,
    required Network network,
    DateTime? birthday,
  }) async {
    // Check BIP49 first for Aqua compatibility
    final testBip49Wallet = await _walletRepository.createWallet(
      seed: seed,
      network: network,
      scriptType: ScriptType.bip49,
      isDefault: false,
      birthday: birthday,
      sync: true, // Must sync to detect on-chain funds
    );

    final hasFunds = testBip49Wallet.balanceSat > BigInt.zero;
    await _walletRepository.deleteWallet(walletId: testBip49Wallet.id);

    if (hasFunds) {
      log.fine(
        'Detected BIP49 Liquid wallet with balance: ${testBip49Wallet.balanceSat}',
      );
      log.warning(
        'Importing legacy BIP49 Liquid wallet (Aqua compatibility). '
        'Consider migrating to BIP84 for lower transaction fees.',
      );
      return ScriptType.bip49;
    }

    log.fine('No funds in BIP49 Liquid wallet, using BIP84');
    return ScriptType.bip84;
  }
}
