import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/features/trezor/domain/entities/trezor_account.dart';

abstract class TrezorDeviceRepository {
  Future<List<TrezorAccount>> getAccounts({
    required int startIndex,
    required int count,
    required ScriptType scriptType,
  });

  /// Hex (8 chars, 4 bytes) fingerprint of the master public key (path "m").
  ///
  /// Required to construct descriptors with a valid BIP32 origin
  /// (`[fp/84'/0'/0']zpub…`). The implementation caches the value after the
  /// first fetch since master fingerprint never changes for a given device.
  Future<String> getMasterFingerprint();
}
