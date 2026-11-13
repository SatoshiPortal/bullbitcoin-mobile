import 'dart:async';

import 'package:bb_mobile/features/fund_exchange/domain/usecases/get_confidential_sepa_funding_availability_usecase.dart';
import 'package:bb_mobile/features/fund_exchange/domain/external_link_port.dart';
import 'package:bb_mobile/features/fund_exchange/domain/repositories/funding_repository.dart';
import 'package:bb_mobile/features/fund_exchange/domain/usecases/get_fund_exchange_user_summary_usecase.dart';
import 'package:bb_mobile/features/fund_exchange/domain/usecases/get_funding_details_usecase.dart';
import 'package:bb_mobile/features/fund_exchange/domain/usecases/list_funding_institutions_usecase.dart';
import 'package:bb_mobile/features/fund_exchange/domain/usecases/open_funding_payment_link_usecase.dart';
import 'package:bb_mobile/features/fund_exchange/domain/usecases/register_responsibility_consent_usecase.dart';
import 'package:bb_mobile/features/fund_exchange/domain/fund_exchange_failure.dart';
import 'package:bb_mobile/features/fund_exchange/domain/entities/funding_jurisdiction.dart';
import 'package:bb_mobile/features/fund_exchange/domain/entities/funding_details.dart';
import 'package:bb_mobile/features/fund_exchange/domain/entities/funding_institution.dart';
import 'package:bb_mobile/features/fund_exchange/domain/entities/funding_method.dart';
import 'package:bb_mobile/features/fund_exchange/presentation/fund_exchange_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:primitives/primitives.dart';

const _link = 'https://pay.example.com/abc';

class _MockGetUserSummary extends Mock
    implements GetFundExchangeUserSummaryUsecase {}

class _UnusedRepository implements FundingRepository {
  const _UnusedRepository();

  @override
  Future<Result<FundingDetails, FundExchangeFailure>> getFundingDetails({
    required FundingMethod fundingMethod,
  }) async => throw UnimplementedError();

  @override
  Future<Result<List<FundingInstitution>, FundExchangeFailure>>
  listInstitutions({required FundingJurisdiction jurisdiction}) async =>
      throw UnimplementedError();

  @override
  Future<Result<void, FundExchangeFailure>>
  registerResponsibilityConsent() async => throw UnimplementedError();
}

/// Holds each launch open until the test releases it, so a second request can
/// be made while the first is genuinely still in flight.
class _BlockingExternalLink implements ExternalLinkPort {
  final List<Uri> opened = [];
  final List<Completer<Result<void, FundExchangeFailure>>> pending = [];

  @override
  Future<Result<void, FundExchangeFailure>> open(Uri url) {
    opened.add(url);
    final completer = Completer<Result<void, FundExchangeFailure>>();
    pending.add(completer);
    return completer.future;
  }
}

FundExchangeBloc _blocWith(ExternalLinkPort link) {
  const repository = _UnusedRepository();
  return FundExchangeBloc(
    getFundExchangeUserSummaryUsecase: _MockGetUserSummary(),
    getFundingDetailsUsecase: const GetFundingDetailsUsecase(
      fundingRepository: repository,
    ),
    listFundingInstitutionsUsecase: const ListFundingInstitutionsUsecase(
      fundingRepository: repository,
    ),
    registerResponsibilityConsentUsecase:
        const RegisterResponsibilityConsentUsecase(
          fundingRepository: repository,
        ),
    openFundingPaymentLinkUsecase: OpenFundingPaymentLinkUsecase(
      externalLink: link,
    ),
    getConfidentialSepaFundingAvailabilityUsecase: _NoConfidentialSepa(),
  );
}

class _NoConfidentialSepa
    implements GetConfidentialSepaFundingAvailabilityUsecase {
  @override
  Future<Result<bool, FundExchangeFailure>> execute() async => const Ok(false);
}

void main() {
  test('a second request while one is in flight is ignored', () async {
    final link = _BlockingExternalLink();
    final bloc = _blocWith(link);
    addTearDown(bloc.close);

    bloc.add(
      const FundExchangeEvent.paymentLinkOpenRequested(paymentLink: _link),
    );
    await Future<void>.delayed(Duration.zero);
    expect(bloc.state.isOpeningPaymentLink, isTrue);

    // The double tap.
    bloc.add(
      const FundExchangeEvent.paymentLinkOpenRequested(paymentLink: _link),
    );
    await Future<void>.delayed(Duration.zero);

    expect(
      link.opened,
      hasLength(1),
      reason: 'the payment page must not be opened twice',
    );

    link.pending.single.complete(const Ok(null));
    await Future<void>.delayed(Duration.zero);
    expect(bloc.state.isOpeningPaymentLink, isFalse);
  });

  test('the flag clears on failure so the user can retry', () async {
    final link = _BlockingExternalLink();
    final bloc = _blocWith(link);
    addTearDown(bloc.close);

    bloc.add(
      const FundExchangeEvent.paymentLinkOpenRequested(paymentLink: _link),
    );
    await Future<void>.delayed(Duration.zero);
    link.pending.single.complete(
      const Err(FundExchangePaymentLinkUnavailableFailure('nope')),
    );
    await Future<void>.delayed(Duration.zero);

    expect(bloc.state.isOpeningPaymentLink, isFalse);
    expect(
      bloc.state.openPaymentLinkFailure,
      isA<FundExchangePaymentLinkUnavailableFailure>(),
    );

    bloc.add(
      const FundExchangeEvent.paymentLinkOpenRequested(paymentLink: _link),
    );
    await Future<void>.delayed(Duration.zero);

    expect(link.opened, hasLength(2), reason: 'a retry must be possible');
  });
}
