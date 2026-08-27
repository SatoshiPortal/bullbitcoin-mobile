import 'package:bb_mobile/generated/l10n/localization.dart';

class FundExchangeApiErrorCopy {
  FundExchangeApiErrorCopy._();

  static String? title(String? code, AppLocalizations loc) => switch (code) {
    'ERR_ORD_PO404' => loc.fundExchangeErrorTitleOrdPo404,
    'ERR_RCP_PO404' => loc.fundExchangeErrorTitleRcpPo404,
    'ERR_RCP_POSINPE404' => loc.fundExchangeErrorTitleRcpPosinpe404,
    'ERR_ORD_KYC400' => loc.fundExchangeErrorTitleOrdKyc400,
    'ERR_ORD_COP400' => loc.fundExchangeErrorTitleOrdCop400,
    'ERR_ORD_CSRCP400' => loc.fundExchangeErrorTitleOrdCsrcp400,
    'ERR_RCP_400' => loc.fundExchangeErrorTitleRcp400,
    _ => null,
  };

  static String message({
    required String? code,
    required String backendMessage,
    required Map<String, String>? messageData,
    required AppLocalizations loc,
  }) {
    if (code == 'ERR_RCP_400') {
      return backendMessage.isNotEmpty
          ? backendMessage
          : loc.fundExchangeErrorRcp400;
    }

    return switch (code) {
      'ERR_ORD_PO404' => loc.fundExchangeErrorOrdPo404,
      'ERR_RCP_PO404' => loc.fundExchangeErrorRcpPo404,
      'ERR_RCP_POSINPE404' => loc.fundExchangeErrorRcpPosinpe404,
      'ERR_ORD_KYC400' => loc.fundExchangeErrorOrdKyc400(
        messageData?['missingFields'] ?? '',
      ),
      'ERR_ORD_COP400' => loc.fundExchangeErrorOrdCop400(
        messageData?['error'] ?? backendMessage,
      ),
      'ERR_ORD_CSRCP400' => loc.fundExchangeErrorOrdCsrcp400(
        messageData?['iban'] ?? '',
      ),
      _ => loc.fundExchangeErrorLoadingDetails,
    };
  }
}
