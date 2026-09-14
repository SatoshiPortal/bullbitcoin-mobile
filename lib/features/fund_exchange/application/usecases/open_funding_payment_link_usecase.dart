import 'package:bb_mobile/features/fund_exchange/application/ports/external_link_port.dart';
import 'package:bb_mobile/features/fund_exchange/domain/fund_exchange_failure.dart';
import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';

class OpenFundingPaymentLinkCommand {
  final String paymentLink;

  const OpenFundingPaymentLinkCommand({required this.paymentLink});
}

class OpenFundingPaymentLinkResult {
  const OpenFundingPaymentLinkResult();
}

/// A payment link is a web address. Nothing else is launchable from here.
const _allowedSchemes = {'http', 'https'};

class OpenFundingPaymentLinkUsecase {
  final ExternalLinkPort _externalLink;

  const OpenFundingPaymentLinkUsecase({required this._externalLink});

  @useResult
  Future<Result<OpenFundingPaymentLinkResult, FundExchangeFailure>> execute(
    OpenFundingPaymentLinkCommand command,
  ) async {
    // The link is backend-supplied, so an unparseable value is a normal
    // failure rather than a bug — `tryParse` keeps it out of the throw path.
    final url = Uri.tryParse(command.paymentLink);
    // Only web links may be opened. The browser launch would reject anything
    // else anyway, but stating it here keeps a compromised or malformed
    // backend response from reaching the platform channel at all.
    if (url == null || !_allowedSchemes.contains(url.scheme)) {
      return const Err(FundExchangePaymentLinkUnavailableFailure());
    }

    final result = await _externalLink.open(url);

    return result.map((_) => const OpenFundingPaymentLinkResult());
  }
}
