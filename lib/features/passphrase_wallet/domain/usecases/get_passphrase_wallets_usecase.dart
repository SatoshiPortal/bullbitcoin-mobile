import 'package:bb_mobile/core/seed/domain/usecases/get_default_seed_usecase.dart';
import 'package:bb_mobile/core/settings/domain/get_settings_usecase.dart';
import 'package:bb_mobile/core/utils/descriptor_derivation.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_provenance.dart';
import 'package:bb_mobile/features/keychain_manifest/public/keychain_manifest_facade.dart';
import 'package:bb_mobile/features/passphrase_wallet/domain/entities/passphrase_wallet.dart';
import 'package:bb_mobile/features/passphrase_wallet/domain/passphrase_wallet_failure.dart';
import 'package:primitives/primitives.dart' show Err, Fingerprint, Ok, Result;

/// Reads every passphrase wallet the active mnemonic has created, from the
/// manifest that is canonical for them (spec 20.1, decision 2).
///
/// Loaded and locked are deliberately not decided here: the wallet feature owns
/// that fact and the page Cubit reads it from there, so the page has one
/// observer of it rather than two disagreeing ones (spec F20).
final class GetPassphraseWalletsUsecase {
  final GetDefaultSeedUsecase _getDefaultSeed;
  final GetSettingsUsecase _getSettings;
  final KeychainManifestFacade _manifest;

  const GetPassphraseWalletsUsecase(
    this._getDefaultSeed,
    this._getSettings,
    this._manifest,
  );

  Future<Result<List<PassphraseWalletRecord>, PassphraseWalletFailure>>
  execute() async {
    final settings = await _getSettings.execute();
    final seed = await _getDefaultSeed.execute(
      environment: settings.environment,
    );
    final Fingerprint parentFingerprint;
    switch (seed) {
      case Ok(:final value):
        parentFingerprint = Fingerprint(value.masterFingerprint);
      case Err():
        return const Err(PassphraseWalletSeedFailure());
    }
    final manifest = await _manifest.readManifest(parentFingerprint);
    final KeychainManifest value;
    switch (manifest) {
      case Ok(value: final loaded):
        value = loaded;
      case Err():
        return const Err(PassphraseWalletManifestFailure());
    }
    final network = Network.fromEnvironment(
      isTestnet: settings.environment.isTestnet,
      isLiquid: false,
    );
    final records = <PassphraseWalletRecord>[];
    try {
      for (final entry in value.entries) {
        for (final wallet
            in entry.materializations.whereType<KeychainManifestWallet>()) {
          if (wallet.provenance != WalletProvenance.defaultSeedPassphrase ||
              wallet.network != network) {
            continue;
          }
          if (wallet.scriptType != ScriptType.bip84 ||
              wallet.descriptor == null) {
            return const Err(PassphraseWalletDescriptorFailure());
          }
          records.add(
            PassphraseWalletRecord(
              walletId: wallet.walletId,
              parentFingerprint: parentFingerprint,
              seedFingerprint: wallet.childSeedFingerprint,
              network: wallet.network,
              descriptor:
                  DescriptorDerivation.canonicalCombinedPublicBitcoinDescriptor(
                    wallet.descriptor!,
                    wallet.network,
                  ),
              createdAt: DateTime.fromMillisecondsSinceEpoch(
                wallet.createdAt * 1000,
                isUtc: true,
              ),
              label: wallet.label,
              hint: entry.description,
            ),
          );
        }
      }
    } on FormatException {
      return const Err(PassphraseWalletDescriptorFailure());
    }
    records.sort((left, right) => left.createdAt.compareTo(right.createdAt));
    return Ok(List.unmodifiable(records));
  }
}
