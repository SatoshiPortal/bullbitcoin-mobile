import 'package:bb_mobile/core/utils/constants.dart';

class MempoolUrl {
  static String bitcoinTxidUrl(String txid) {
    return 'https://${ApiServiceConstants.bbMempoolUrlPath}/tx/$txid';
  }

  static String liquidTxidUrl(String unblindedUrl) {
    return 'https://${ApiServiceConstants.bbLiquidMempoolUrlPath}/$unblindedUrl';
  }
}
