import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';

/// Bull's Trezor integration capability surface.
///
/// Trezor Suite is the runtime gatekeeper — it talks to the connected
/// device, refuses operations the specific model can't perform, and
/// surfaces those refusals via the existing _mapError path. The
/// constants below are Bull's *additional, app-side* claim of what
/// it has wired up to invoke Suite for. Anything not in these sets
/// is hidden from the user before a Suite round-trip is attempted.
///
/// When Suite gains or drops support for a script type / network /
/// wallet-type / platform combination, edit the set here — both the
/// gate and any user-visible affordance derived from it stay in
/// sync automatically.

/// Script types Bull will offer at Trezor import time, and therefore
/// the only script types a Bull wallet with `signerDevice == trezor`
/// will ever have. Verify-address and PSBT-sign operations are
/// universally supported by Suite for all three — gating at import
/// is sufficient.
const Set<ScriptType> kTrezorSupportedScriptTypes = {
  ScriptType.bip84,
  ScriptType.bip49,
  ScriptType.bip44,
};

/// Networks Bull will use for Trezor wallets. Currently mainnet-only —
/// matches the hardcoded `isTestnet: false` in TrezorImportCubit's
/// startImport call from the landing screen. Testnet/signet are not
/// exposed to users yet (would require a network picker on the
/// import screen).
const Set<bool> kTrezorSupportedIsTestnetValues = {false};

/// Wallet types supported. Bull's Trezor deeplink protocol covers
/// single-sig only — multisig is supported by Trezor devices but
/// not by Suite's mobile deeplink interface that Bull uses.
const bool kTrezorSupportsMultisig = false;
