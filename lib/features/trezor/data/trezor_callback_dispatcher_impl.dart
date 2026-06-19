import 'package:bb_mobile/features/trezor/data/trezor_connect_datasource.dart';
import 'package:bb_mobile/features/trezor/domain/repositories/trezor_callback_dispatcher.dart';

class TrezorCallbackDispatcherImpl implements TrezorCallbackDispatcher {
  final TrezorConnectDatasource _datasource;

  TrezorCallbackDispatcherImpl({required this._datasource});

  @override
  void handleCallback(Uri uri) => _datasource.handleCallback(uri);
}
