import 'package:async/async.dart';
import 'package:bb_mobile/core/settings/data/settings_repository.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';
import 'package:bb_mobile/core/wallet/data/wallet_signing_material_resolver.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';

/// Publishes the wallets Home may show, whenever the catalog or the loaded
/// private capability changes.
///
/// A wallet a recovery writes reaches Home this way: the import happens with
/// Home already on screen, so nothing navigates and nothing remounts, and the
/// catalog change is the only news there is.
///
/// A locked passphrase wallet keeps its public projection in local storage so
/// remounting stays cheap, but drops out of this catalog and out of normal
/// receive/send flows until it is loaded again.
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
      StreamGroup.merge([
        _resolver.capabilityChanges,
        _wallets.catalogChanges,
      ]).asyncMap((_) async {
        final settings = await _settings.fetch();
        return _wallets.getWallets(environment: settings.environment);
      });
}
