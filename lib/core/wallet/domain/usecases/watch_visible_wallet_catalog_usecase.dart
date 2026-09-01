import 'package:bb_mobile/core/settings/data/settings_repository.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';
import 'package:bb_mobile/core/wallet/data/wallet_signing_material_resolver.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';

/// Publishes the wallets Home may show, whenever the loaded private capability
/// changes.
///
/// A locked passphrase wallet keeps its public projection in local storage so
/// remounting stays cheap, but drops out of this catalog and out of normal
/// receive/send flows until it is loaded again (spec 20.2).
final class WatchVisibleWalletCatalogUsecase {
  final WalletRepository _wallets;
  final SettingsRepository _settings;
  final WalletSigningMaterialResolver _resolver;

  const WatchVisibleWalletCatalogUsecase(
    this._wallets,
    this._settings,
    this._resolver,
  );

  Stream<List<Wallet>> execute() =>
      _resolver.capabilityChanges.asyncMap((_) async {
        final settings = await _settings.fetch();
        return _wallets.getWallets(environment: settings.environment);
      });
}
