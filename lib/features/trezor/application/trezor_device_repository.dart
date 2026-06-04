import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/features/trezor/domain/entities/trezor_account.dart';
import 'package:bb_mobile/features/trezor/domain/entities/trezor_signed_psbt.dart';

abstract class TrezorDeviceRepository {
  Future<List<TrezorAccount>> getAccounts({
    required int startIndex,
    required int count,
    required ScriptType scriptType,
  });

  Future<TrezorSignedPsbt> signPsbt({
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
  });
}
