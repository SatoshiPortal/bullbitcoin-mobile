import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/btcpay/domain/btcpay_connection.dart';
import 'package:bb_mobile/features/btcpay/domain/btcpay_failure.dart';
import 'package:meta/meta.dart';

export 'package:bb_mobile/features/btcpay/domain/btcpay_connection.dart'
    show BtcpayConnection, BtcpayConnectionStatus;
export 'package:bb_mobile/features/btcpay/domain/btcpay_failure.dart'
    show BtcpayFailure, BtcpayStorageFailure;
export 'package:bb_mobile/features/btcpay/domain/btcpay_wallet.dart'
    show BtcpayWalletNetwork;
export 'package:bb_mobile/features/btcpay/domain/samrock_pairing_request.dart'
    show SamRockSetupCapability;

/// Cross-feature contract for the BTCPay/SamRock connection. Callback-injection
/// shape (the Lightning Address / Payment Page / POS facade precedent): the
/// locator wires the callback to [GetBtcpayConnectionUsecase], keeping the
/// feature's usecases and repository internal. Read-only — the hub never
/// pairs, only reads the current connection to render status.
class BtcpayFacade {
  final Future<Result<BtcpayConnection?, BtcpayFailure>> Function()
  _connectionCallback;

  const BtcpayFacade({
    required Future<Result<BtcpayConnection?, BtcpayFailure>> Function()
    connection,
  }) : _connectionCallback = connection;

  /// The current paired connection; null when no BTCPay server is paired.
  @useResult
  Future<Result<BtcpayConnection?, BtcpayFailure>> connection() =>
      _connectionCallback();
}
