import 'package:bb_mobile/features/trezor/data/trezor_connect_datasource.dart';
import 'package:bb_mobile/features/trezor/domain/trezor_callback_port.dart';

class TrezorCallbackPortImpl implements TrezorCallbackPort {
  final TrezorConnectDatasource _datasource;

  TrezorCallbackPortImpl({required this._datasource});

  @override
  void handleCallback(Uri uri) => _datasource.handleCallback(uri);
}
