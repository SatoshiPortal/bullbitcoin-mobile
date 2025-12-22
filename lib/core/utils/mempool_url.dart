import 'package:bb_mobile/core/mempool/application/usecases/get_active_mempool_server_usecase.dart';

class MempoolUrlService {
  final GetActiveMempoolServerUsecase _getActiveMempoolServerUsecase;

  const MempoolUrlService({
    required GetActiveMempoolServerUsecase getActiveMempoolServerUsecase,
  }) : _getActiveMempoolServerUsecase = getActiveMempoolServerUsecase;

  Future<String> bitcoinTxidUrl(
    String txid, {
    required bool isTestnet,
  }) async {
    final server = await _getActiveMempoolServerUsecase.execute(
      isTestnet: isTestnet,
      isLiquid: false,
    );
    return '${server.fullUrl}/tx/$txid';
  }

  Future<String> liquidTxidUrl(
    String unblindedUrl, {
    required bool isTestnet,
  }) async {
    final server = await _getActiveMempoolServerUsecase.execute(
      isTestnet: isTestnet,
      isLiquid: true,
    );
    return '${server.fullUrl}/$unblindedUrl';
  }
}
