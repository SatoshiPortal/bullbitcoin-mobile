import 'package:bb_mobile/features/fund_exchange/application/ports/external_link_port.dart';
import 'package:bb_mobile/features/fund_exchange/application/usecases/open_funding_payment_link_usecase.dart';
import 'package:bb_mobile/features/fund_exchange/domain/fund_exchange_failure.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';

/// Records what it was asked to open, and answers with [result].
class _RecordingExternalLink implements ExternalLinkPort {
  final Result<void, FundExchangeFailure> result;
  final List<Uri> opened = [];

  _RecordingExternalLink([this.result = const Ok(null)]);

  @override
  Future<Result<void, FundExchangeFailure>> open(Uri url) async {
    opened.add(url);
    return result;
  }
}

void main() {
  test('a well-formed link is handed to the port', () async {
    final link = _RecordingExternalLink();
    final usecase = OpenFundingPaymentLinkUsecase(externalLink: link);

    final result = await usecase.execute(
      const OpenFundingPaymentLinkCommand(
        paymentLink: 'https://pay.example.com/abc',
      ),
    );

    expect(
      result,
      isA<Ok<OpenFundingPaymentLinkResult, FundExchangeFailure>>(),
    );
    expect(link.opened.single.toString(), 'https://pay.example.com/abc');
  });

  // The link is backend-supplied, so a malformed value must be a Result, not a
  // thrown FormatException escaping into the bloc.
  test(
    'a malformed link is a sanitized failure, and is never opened',
    () async {
      for (final bad in [
        '',
        'not a url',
        '   ',
        '::::',
        // No scheme at all.
        'pay.example.com/abc',
        // Schemes that are not web links must not reach the platform channel,
        // however plausible they look.
        'javascript:alert(1)',
        'file:///etc/passwd',
        'intent://scan/#Intent;scheme=zxing;end',
        'bitcoin:bc1qexample',
        'HTTPX://pay.example.com',
      ]) {
        final link = _RecordingExternalLink();
        final usecase = OpenFundingPaymentLinkUsecase(externalLink: link);

        final result = await usecase.execute(
          OpenFundingPaymentLinkCommand(paymentLink: bad),
        );

        expect(
          result,
          isA<Err<OpenFundingPaymentLinkResult, FundExchangeFailure>>(),
          reason: '"$bad" should not reach the launcher',
        );
        expect(
          (result as Err).failure,
          isA<FundExchangePaymentLinkUnavailableFailure>(),
        );
        expect(link.opened, isEmpty);
      }
    },
  );

  test('plain http is still allowed', () async {
    final link = _RecordingExternalLink();
    final usecase = OpenFundingPaymentLinkUsecase(externalLink: link);

    final result = await usecase.execute(
      const OpenFundingPaymentLinkCommand(
        paymentLink: 'http://pay.example.com/abc',
      ),
    );

    expect(
      result,
      isA<Ok<OpenFundingPaymentLinkResult, FundExchangeFailure>>(),
    );
    expect(link.opened, hasLength(1));
  });

  test('a port failure is forwarded unchanged', () async {
    final link = _RecordingExternalLink(
      const Err(FundExchangePaymentLinkUnavailableFailure('PlatformException')),
    );
    final usecase = OpenFundingPaymentLinkUsecase(externalLink: link);

    final result = await usecase.execute(
      const OpenFundingPaymentLinkCommand(
        paymentLink: 'https://pay.example.com/abc',
      ),
    );

    final failure = (result as Err).failure as FundExchangeFailure;
    expect(failure, isA<FundExchangePaymentLinkUnavailableFailure>());
    expect(failure.logMessage, 'PlatformException');
  });
}
