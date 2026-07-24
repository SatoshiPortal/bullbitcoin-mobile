import 'package:bb_mobile/core/settings/domain/repositories/settings_repository.dart';

/// Whether compact block filter (BIP157/158) sync is available to offer for
/// the current build and the user's developer settings.
///
/// This is the single source of truth for the CBF developer/beta gate.
/// Every call site that used to duplicate its own `kDebugMode` +
/// `isDevModeEnabled` check —
/// `WalletSyncRoutingRepository`, `CreateDefaultWalletsUsecase`,
/// `ImportWalletUsecase`, `ImportWatchOnlyDescriptorUsecase`, and
/// `ImportWatchOnlyXpubUsecase` — now calls this instead.
///
/// Pure Dart, no Flutter import. `kDebugMode` lives in
/// `package:flutter/foundation.dart`, which a domain use-case must not
/// depend on; `bool.fromEnvironment('dart.vm.product')` is the equivalent
/// compile-time constant from the Dart language itself (true only in a
/// `--release` build), so this stays Flutter-free while keeping the same
/// "debug or profile build" meaning `kDebugMode`'s non-product half relies
/// on.
///
/// Available when either:
/// - [enableCbfFlag] was set at compile time
///   (`--dart-define=ENABLE_CBF=true`, see `make android-cbf-debug`), or
/// - this is not a release build AND developer mode is enabled in settings.
///
/// Tor is deliberately not part of this selection gate. A user choice must
/// remain persisted while Tor is enabled instead of silently becoming
/// Electrum. `WalletSyncRoutingRepository` checks Tor immediately before
/// starting a CBF session and returns a typed failure without opening a peer
/// connection.
class CheckCompactBlockFiltersAvailableUsecase {
  final SettingsRepository _settingsRepository;

  CheckCompactBlockFiltersAvailableUsecase({required this._settingsRepository});

  /// Set only via `--dart-define=ENABLE_CBF=true` on an explicit beta/debug
  /// build (e.g. `make android-cbf-debug`). This bypasses the
  /// developer-mode settings toggle entirely, on purpose, so a demo/beta
  /// APK can ship the wizard's compact-filter step without also turning on
  /// unrelated developer features.
  ///
  /// This flag must never be set on a production release build ahead of
  /// the compact-block-filters rollout approval — see
  /// `docs/compact-block-filters-pr-roadmap.md`. It is read only by this
  /// use-case and by the developer per-wallet tile's visibility check
  /// (`WalletOptionsScreen`); it is never wired into any release build
  /// target in the makefile.
  static const bool enableCbfFlag = bool.fromEnvironment('ENABLE_CBF');

  /// The Dart-language compile-time equivalent of `!kDebugMode &&
  /// !kProfileMode` — true only for a `--release` build. Available without
  /// importing Flutter.
  ///
  /// Public (not just this use-case's private gate) so a call site that
  /// cannot instantiate this use-case at all — `WizardPage`, which runs
  /// before `Bull.init`'s locator exists and so has no `SettingsRepository`
  /// to construct one with — can still read the same compile-time half of
  /// the gate directly. See `WizardPage.available`.
  static const bool isProductionBuild = bool.fromEnvironment('dart.vm.product');

  Future<bool> execute() async {
    final settings = await _settingsRepository.fetch();
    if (enableCbfFlag) return true;
    return !isProductionBuild && settings.isDevModeEnabled == true;
  }
}
