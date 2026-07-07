import 'package:bb_mobile/features/btcpay/domain/btcpay_connection.dart';

export 'package:bb_mobile/features/btcpay/domain/btcpay_connection.dart'
    show BtcpayConnection, BtcpayConnectionStatus;

/// Cross-feature contract for the BTCPay/SamRock connection. Callback-injection
/// shape (the Lightning Address / Payment Page / POS facade precedent): the
/// locator wires the callback to [GetBtcpayConnectionUsecase], keeping the
/// feature's usecases and repository internal. Read-only — the hub never
/// pairs, only reads the current connection to render status.
class BtcpayFacade {
  final Future<BtcpayConnection?> Function() _connectionCallback;

  const BtcpayFacade({
    required Future<BtcpayConnection?> Function() connection,
  }) : _connectionCallback = connection;

  /// The current paired connection; null when no BTCPay server is paired.
  Future<BtcpayConnection?> connection() => _connectionCallback();
}
