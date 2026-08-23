import 'package:bb_mobile/core/bip85/data/bip85_repository.dart';
import 'package:bb_mobile/core/bip85/domain/bip85_derivation_entity.dart';
import 'package:bb_mobile/core/bip85/domain/errors/bip85_failure.dart';
import 'package:bb_mobile/core/seed/data/repository/seed_repository.dart';
import 'package:bb_mobile/core/utils/bip32_derivation.dart';
import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';
import 'package:meta/meta.dart';
import 'package:bb_mobile/core/settings/data/settings_repository.dart';

class DeriveNextBip85HexFromDefaultWalletUsecase {
  final Bip85Repository _bip85Repository;
  final WalletRepository _walletRepository;
  final SeedRepository _seedRepository;
  final SettingsRepository _settingsRepository;

  DeriveNextBip85HexFromDefaultWalletUsecase({
    required this._bip85Repository,
    required this._walletRepository,
    required this._seedRepository,
    required this._settingsRepository,
  });

  @useResult
  Future<Result<({String derivation, String hex}), Bip85Failure>> execute({
    required int length,
    String? alias,
  }) async {
    try {
      // Derive from the default wallet of the environment the app is actually
      // running in: a hardcoded mainnet lookup finds no wallet on testnet.
      final settings = await _settingsRepository.fetch();
      final wallets = await _walletRepository.getWallets(
        onlyDefaults: true,
        onlyBitcoin: true,
        environment: settings.environment,
      );
      if (wallets.isEmpty) return const Err(Bip85NoDefaultWalletFailure());
      final defaultWallet = wallets.first;

      final defaultSeed = await _seedRepository.get(
        defaultWallet.masterFingerprint,
      );

      final xprv = Bip32Derivation.getCanonicalRootXprvFromSeed(
        defaultSeed.bytes,
      );

      const application = Bip85Application.hex;
      final indexResult = await _bip85Repository.fetchNextIndexForApplication(
        application,
      );
      switch (indexResult) {
        case Err(:final failure):
          return Err(failure);
        case Ok(:final value):
          return _bip85Repository.deriveHex(
            xprvBase58: xprv,
            length: length,
            index: value,
            alias: alias,
          );
      }
    } catch (e, st) {
      log.severe(
        message: 'DeriveNextBip85HexFromDefaultWalletUsecase failed',
        error: e.runtimeType,
        trace: st,
      );
      return const Err(
        Bip85UnexpectedFailure('BIP85 next-hex derivation failed'),
      );
    }
  }
}
