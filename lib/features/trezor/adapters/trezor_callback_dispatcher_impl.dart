import 'package:bb_mobile/features/trezor/application/trezor_callback_dispatcher.dart';
import 'package:bb_mobile/features/trezor/frameworks/trezor_connect_datasource.dart';

class TrezorCallbackDispatcherImpl implements TrezorCallbackDispatcher {
  final TrezorConnectDatasource _datasource;

  TrezorCallbackDispatcherImpl({required this._datasource});

  @override
  void handleCallback(Uri uri) => _datasource.handleCallback(uri);
}
