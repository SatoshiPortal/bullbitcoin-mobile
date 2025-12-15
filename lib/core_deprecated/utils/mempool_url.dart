import 'package:bb_mobile/core_deprecated/utils/constants.dart';

class MempoolUrl {
  static String bitcoinTxidUrl(String txid, {required bool isTestnet}) {
    return 'https://${isTestnet ? ApiServiceConstants.testnetMempoolUrlPath : ApiServiceConstants.bbMempoolUrlPath}/tx/$txid';
  }

  static String liquidTxidUrl(String unblindedUrl, {required bool isTestnet}) {
    return 'https://${isTestnet ? ApiServiceConstants.bbLiquidMempoolTestnetUrlPath : ApiServiceConstants.bbLiquidMempoolUrlPath}/$unblindedUrl';
  }
}
