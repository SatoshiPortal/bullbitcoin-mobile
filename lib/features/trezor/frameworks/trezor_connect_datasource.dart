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
}
