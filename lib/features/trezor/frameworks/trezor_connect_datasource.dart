import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:trezor_connect/trezor_connect.dart';

class TrezorConnectDatasource {
  final TrezorConnect _connect;

  TrezorConnectDatasource({required TrezorConnect connect})
    : _connect = connect;

  /// Exposed so `TrezorDeeplinkListener` can call `handleCallback` on the
  /// same instance the package uses internally for `_callbacks` map lookup.
  TrezorConnect get connect => _connect;

  Future<List<TrezorAddressPublicKey>> getPublicKeyBundle(
    List<String> paths,
  ) async {
    final params = paths
        .map((path) => TrezorGetPublicKeyParams(path: path, coin: 'btc'))
        .toList();

    final result = await _connect.getPublicKeyBundle(params);

    if (result == null) {
      throw Exception('Empty response from Trezor Suite');
    }

    return result;
  }

  /// Asks Trezor Suite to display the address for `derivationPath` on the
  /// device. Trezor derives the address locally from its own master seed
  /// and renders it for the user to compare against the in-app QR.
  ///
  /// The actual security check is the user comparing the
  /// on-device display against the in-app QR/address;
  ///
  /// Returns `true` when the user confirms on device.
  Future<bool> verifyAddress({
    required String address,
    required String derivationPath,
    required ScriptType scriptType,
  }) async {
    // Trezor Suite's deeplinking path parser rejects the `h` notation that
    // BDK / satoshifier emit in `wallet.derivationPath` (e.g.
    // `m/84h/0h/0h/0/0`) with `Failure_DataError`. The canonical Trezor
    // hardened-component marker is `'` — the same notation that our
    // already-working `getPublicKeyBundle` call uses (`m/84'/0'/0'`).
    // Normalize before sending.
    final normalizedPath = derivationPath.replaceAll('h', "'");

    final result = await _connect.getAddress(
      normalizedPath,
      showOnTrezor: true,
      coin: 'btc',
      scriptType: _addressScriptTypeFor(scriptType),
    );

    return result != null;
  }

  String _addressScriptTypeFor(ScriptType scriptType) => switch (scriptType) {
    ScriptType.bip84 => 'SPENDWITNESS',
    ScriptType.bip49 => 'SPENDP2SHWITNESS',
    ScriptType.bip44 => 'SPENDADDRESS',
  };
}
