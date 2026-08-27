import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/btcpay/domain/btcpay_connection.dart';
import 'package:bb_mobile/features/btcpay/domain/btcpay_failure.dart';
import 'package:bb_mobile/features/btcpay/domain/samrock_pairing_request.dart';
import 'package:meta/meta.dart';

class PreviewBtcpaySamRockPairingUsecase {
  final SamRockPairingRequestParser _parser;

  const PreviewBtcpaySamRockPairingUsecase({required this._parser});

  @useResult
  Result<BtcpaySamRockPairingPreview, BtcpayFailure> execute(
    String pairingUrl,
  ) {
    return _parser
        .parse(pairingUrl)
        .map(
          (request) => BtcpaySamRockPairingPreview(
            serverUrl: btcpayServerUrlFor(request),
            supportsBitcoinChain: request.supportsBitcoinChain,
            supportsLiquidChain: request.supportsLiquidChain,
            supportsLightning: request.supportsLightning,
          ),
        );
  }
}

class BtcpaySamRockPairingPreview {
  final String serverUrl;
  final bool supportsBitcoinChain;
  final bool supportsLiquidChain;
  final bool supportsLightning;

  const BtcpaySamRockPairingPreview({
    required this.serverUrl,
    required this.supportsBitcoinChain,
    required this.supportsLiquidChain,
    required this.supportsLightning,
  });
}
