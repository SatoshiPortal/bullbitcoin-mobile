import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/btcpay/domain/btcpay_connection.dart';
import 'package:bb_mobile/features/btcpay/domain/btcpay_failure.dart';
import 'package:meta/meta.dart';

abstract interface class BtcpayConnectionRepository {
  @useResult
  Future<Result<BtcpayConnection?, BtcpayFailure>> getConnection(
    Environment environment,
  );

  @useResult
  Future<Result<void, BtcpayFailure>> saveConnection(
    BtcpayConnection connection,
  );
}
