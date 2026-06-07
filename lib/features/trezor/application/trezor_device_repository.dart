import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/features/trezor/domain/entities/trezor_account.dart';

abstract class TrezorDeviceRepository {
  /// Fetches account 0 (`m/<purpose>'/<coin>'/0'`) for the chosen
  /// [scriptType] from the connected Trezor via Suite. Bull does not
  /// currently expose account selection; if multi-account support is
  /// ever added (e.g. account dropdown on import), reintroduce a
  /// plural API here and route the dropdown selection through it.
  Future<TrezorAccount> getDefaultAccount({
    required ScriptType scriptType,
    required bool isTestnet,
  });

  Future<String> signPsbt({
    required String psbtBase64,
    required bool isTestnet,
    required ScriptType scriptType,
  });

  /// Asks Trezor Suite to display the expected address on the device so the
  /// user can compare it against the in-app QR. Returns `true` when the
  /// user confirms on device.
  Future<bool> verifyAddress({
    required String address,
    required String derivationPath,
    required ScriptType scriptType,
    required bool isTestnet,
  });
}
