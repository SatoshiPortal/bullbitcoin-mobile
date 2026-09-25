import 'package:bb_mobile/core/bip85/data/bip85_repository.dart';
import 'package:bb_mobile/core/bip85/domain/bip85_derivation_entity.dart';
import 'package:bb_mobile/core/bip85/domain/errors/bip85_failure.dart';
import 'package:secrets/secrets.dart';
import 'package:primitives/primitives.dart' show Fingerprint;
import 'package:bull_logger/bull_logger.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';
import 'package:meta/meta.dart';
import 'package:bb_mobile/core/settings/data/settings_repository.dart';

class DeriveNextBip85HexFromDefaultWalletUsecase {
  final Bip85Repository _bip85Repository;
  final WalletRepository _walletRepository;
  final Secrets _secrets;
  final SettingsRepository _settingsRepository;

  DeriveNextBip85HexFromDefaultWalletUsecase({
    required this._bip85Repository,
    required this._walletRepository,
    required this._secrets,
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

      final secret = switch (await _secrets.fetch(
        Fingerprint(defaultWallet.masterFingerprint),
      )) {
        Ok(:final value) => value,
        Err(:final failure) => throw StateError(failure.runtimeType.toString()),
      };

      const application = Bip85Application.hex;
      final indexResult = await _bip85Repository.fetchNextIndexForApplication(
        application,
      );
      switch (indexResult) {
        case Err(:final failure):
          return Err(failure);
        case Ok(:final value):
          // Derived inside the package — the xprv never comes out — then recorded by the repository under the same path it has always written.
          final hex = switch (await secret.derive.bip85.hex(
            numBytes: length,
            index: value,
          )) {
            Ok(:final value) => value,
            Err(:final failure) => throw StateError(
              failure.runtimeType.toString(),
            ),
          };
          return (await _bip85Repository.recordHex(
            xprvFingerprint: secret.id.hex,
            length: length,
            index: value,
            alias: alias,
          )).map((derivation) => (derivation: derivation, hex: hex));
      }
    } catch (e, st) {
      log.severe(
        message: 'DeriveNextBip85HexFromDefaultWalletUsecase failed',
        error: e,
        trace: st,
      );
      return Err(Bip85UnexpectedFailure(e.toString()));
    }
  }
}
