import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/btcpay/domain/btcpay_failure.dart';
import 'package:bb_mobile/features/btcpay/domain/samrock_pairing_request.dart';
import 'package:meta/meta.dart';

abstract interface class SamRockPairingServicePort {
  @useResult
  Future<Result<void, BtcpayFailure>> submitSetup({
    required SamRockPairingRequest request,
    required Map<String, Object?> payload,
  });
}
