import 'package:bb_mobile/core/blockchain/domain/bitcoin_chain_tip_port.dart';

class GetBitcoinChainTipUsecase {
  final BitcoinChainTipPort _chainTipPort;

  const GetBitcoinChainTipUsecase(this._chainTipPort);

  Future<({int height, int medianTimePast})> execute({
    required bool isTestnet,
  }) => _chainTipPort.getChainTip(isTestnet: isTestnet);
}
