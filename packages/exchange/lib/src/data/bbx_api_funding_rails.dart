import 'package:bbx_api/bbx_api.dart' as bbx;
import 'package:bull_logger/bull_logger.dart';
import 'package:primitives/primitives.dart';

import '../domain/catalog/exchange_catalog.dart';
import '../domain/catalog/jurisdiction.dart';
import '../domain/entities/confidential_sepa_availability.dart';
import '../domain/entities/funding_institution.dart';
import '../domain/entities/user_summary.dart';
import '../domain/entities/virtual_iban.dart';
import '../domain/exchange_call_result.dart';
import '../domain/exchange_failure.dart';
import '../funding/funding_instructions.dart';
import '../funding/funding_request.dart';
import 'bbx_api_virtual_ibans_repository.dart';
import 'exchange_call_classifier.dart';
import 'read_user_summary.dart';

/// The funding calls on one client, as closed results. A missing field the
/// rail shows is [ReadMalformed], never a thrown error or an empty value
/// (FUND-1).
final class BbxApiFundingRails {
  final bbx.Bbx _api;
  final Uri paymentReturnUrl;

  const BbxApiFundingRails(this._api, {required this.paymentReturnUrl});

  Future<ExchangeRead<FundingAccount>> account() async {
    final summary = await readUserSummary(_api);
    if (summary is! ReadGot<UserSummary>) return _same(summary);
    final user = summary.value;
    final ExchangeRead<ConfidentialSepaAvailability> confidentialSepa =
        user.isEligibleForConfidentialSepa
        ? switch (await BbxApiVirtualIbansRepository.findOn(_api)) {
            Ok(value: ActiveVirtualIban()) => const ReadGot(
              ConfidentialSepaAvailability.ready,
            ),
            Ok() => const ReadGot(
              ConfidentialSepaAvailability.needsVirtualIban,
            ),
            Err(:final failure) => readOfFailure(failure),
          }
        : const ReadGot(ConfidentialSepaAvailability.unavailable);
    return switch (confidentialSepa) {
      ReadGot(value: final availability) => ReadGot(
        FundingAccount(
          userNumber: user.userNumber,
          firstName: user.profile.firstName,
          lastName: user.profile.lastName,
          currency: switch (user.currency) {
            final code? => ExchangeCatalog.parse(code),
            null => null,
          },
          restricted: user.isFundingRestricted,
          consented: user.hasConsentedScamWarning,
          confidentialSepa: availability,
        ),
      ),
      _ => _same(confidentialSepa),
    };
  }

  Future<ExchangeRead<bool>> consentOnAccount() async =>
      switch (await readUserSummary(_api)) {
        ReadGot(:final value) => ReadGot(value.hasConsentedScamWarning),
        final other => _same(other),
      };

  /// Only `success: true` is a consent; any other answer may or may not
  /// have recorded it, so the gate re-reads.
  Future<ExchangeWrite<void>> consent() async {
    switch (await _api.users.registerResponsibilityConsent()) {
      case Ok(value: true):
        return const WriteDone(null);
      case Ok():
        log.warning('registerResponsibilityConsent answered without success');
        return const WriteOutcomeUnknown('consent answered without success');
      case Err(:final failure):
        return writeOf(failure);
    }
  }

  Future<ExchangeRead<List<FundingInstitution>>> institutions(
    Jurisdiction jurisdiction,
  ) => exchangeRead<bbx.InstitutionList, List<FundingInstitution>>(
    'listInstitutionCodes',
    () => _api.recipients.listInstitutionCodes(
      countryCode: jurisdiction.code.toLowerCase(),
    ),
    (list) {
      if (list.skippedElements > 0) {
        log.warning(
          'Skipped ${list.skippedElements} unparseable institution elements',
        );
      }
      return [
        for (final institution in list.institutions)
          ?_institution(institution.code, institution.name),
      ];
    },
  );

  Future<ExchangeRead<FundingAnswer>> instructions(FundingRequest request) =>
      switch (request) {
        ProcessorCodeRequest() => _processorCode(request),
        CopPaymentRequest() => _copLink(request),
      };

  Future<ExchangeRead<FundingAnswer>> _processorCode(
    ProcessorCodeRequest request,
  ) async {
    final rail = request.rail;
    final answer = await _api.recipients.getUserPaymentProcessorCode(
      rail.paymentProcessorCode,
    );
    if (_refusal(answer) case final refusal?) {
      return ReadGot(FundingRefused(refusal));
    }
    final read =
        await exchangeRead<
          bbx.PaymentProcessorDetails,
          bbx.PaymentProcessorDetails
        >(
          'getUserPaymentProcessorCode',
          () async => answer,
          (details) => details,
        );
    if (read is! ReadGot<bbx.PaymentProcessorDetails>) return _same(read);
    final rows = <InstructionRow>[];
    for (final field in rail.fields) {
      final value = switch (field) {
        InstructionField.secretAnswer => '${request.userNumber}',
        _ => _wireValue(read.value, field),
      };
      if (value == null || value.trim().isEmpty) {
        log.warning(
          'getUserPaymentProcessorCode: ${rail.name} answer has no '
          '${field.name}',
        );
        return ReadMalformed('missing ${field.name}');
      }
      rows.add(InstructionRow(field, value));
    }
    return ReadGot(FundingInstructionsGot(rail.present(rows)));
  }

  Future<ExchangeRead<FundingAnswer>> _copLink(
    CopPaymentRequest request,
  ) async {
    final answer = await _api.orders.getCopPaymentLink(
      bankCode: request.institution.code,
      amount: request.amount.pesos,
      callbackUrl: paymentReturnUrl.toString(),
    );
    if (_refusal(answer) case final refusal?) {
      return ReadGot(FundingRefused(refusal));
    }
    final read = await exchangeRead<String, String>(
      'getCopPaymentLink',
      () async => answer,
      (link) => link,
    );
    if (read is! ReadGot<String>) return _same(read);
    final link = Uri.tryParse(read.value.trim());
    if (link == null ||
        !(link.isScheme('https') || link.isScheme('http')) ||
        link.host.isEmpty) {
      log.warning('getCopPaymentLink answered a link that is not a web page');
      return const ReadMalformed('payment link is not a web page');
    }
    return ReadGot(FundingInstructionsGot(FundingInstructionLink(link)));
  }

  static FundingRefusal? _refusal(Result<Object?, bbx.BbxFailure> answer) =>
      switch (answer) {
        Err(failure: bbx.BbxRpcFailure(:final apiCode)) => switch (apiCode) {
          'ERR_ORD_PO404' => FundingRefusal.paymentOptionUnavailable,
          'ERR_RCP_PO404' => FundingRefusal.optionNotPermitted,
          'ERR_RCP_POSINPE404' => FundingRefusal.sinpeNotRegistered,
          'ERR_ORD_KYC400' => FundingRefusal.kycIncomplete,
          'ERR_ORD_COP400' => FundingRefusal.copRequestInvalid,
          'ERR_ORD_CSRCP400' => FundingRefusal.sepaVirtualPaymentInactive,
          'ERR_RCP_400' => FundingRefusal.requestInvalid,
          _ => null,
        },
        Ok() || Err() => null,
      };

  /// The one map from an instruction field to the answer's wire field.
  static String? _wireValue(
    bbx.PaymentProcessorDetails details,
    InstructionField field,
  ) => switch (field) {
    InstructionField.beneficiaryName => details.beneficiaryName,
    InstructionField.beneficiaryEmail => details.beneficiaryEmail,
    InstructionField.secretQuestion ||
    InstructionField.transferCode => details.code,
    InstructionField.secretAnswer => null,
    InstructionField.bankAccountDetails => details.bankAccountDetails,
    InstructionField.swift => details.swift,
    InstructionField.institutionNumber => details.institutionNumber,
    InstructionField.transitNumber => details.transitNumber,
    InstructionField.routingNumber => details.routingNumber,
    InstructionField.beneficiaryAddress => details.beneficiaryAddress,
    InstructionField.bankName => details.bankName,
    InstructionField.bankAddress => details.bankAddress,
    InstructionField.billerName => details.billerName,
    InstructionField.iban => details.iban,
    InstructionField.bic => details.bic,
    InstructionField.bankAccountCountry => details.bankAccountCountry,
    InstructionField.bankCountry => details.bankCountry,
    InstructionField.clabe => details.clabe,
    InstructionField.phoneNumber => details.numTelefono,
    InstructionField.cedulaJuridica => details.cedulaJuridica,
    InstructionField.cvu => details.cvu,
  };

  static FundingInstitution? _institution(String code, String name) {
    try {
      return FundingInstitution.create(code: code, name: name);
    } on ArgumentError catch (error, trace) {
      log.warning(
        'Skipped an unparseable institution element',
        error: error,
        trace: trace,
      );
      return null;
    }
  }
}

/// [read] with no value, retyped. Only for reads that are not [ReadGot].
ExchangeRead<T> _same<T>(ExchangeRead<Object?> read) => switch (read) {
  ReadGot() => throw StateError('a read with a value is not retyped'),
  ReadMissing() => ReadMissing<T>(),
  ReadUnreachable(:final reason, :final isNetwork) => ReadUnreachable<T>(
    reason,
    isNetwork: isNetwork,
  ),
  ReadSessionRejected(:final why) => ReadSessionRejected<T>(why),
  ReadMalformed(:final reason) => ReadMalformed<T>(reason),
};

/// The read result of a call that failed before or around the server: the
/// session check of `withClient`, or a repository that still answers
/// [ExchangeFailure].
ExchangeRead<T> readOfFailure<T>(ExchangeFailure failure) => switch (failure) {
  ExchangeNotAuthenticatedFailure() => const ReadSessionRejected(
    ExchangeSessionRejection.signedOut,
  ),
  ExchangeCredentialReadFailure() => const ReadSessionRejected(
    ExchangeSessionRejection.credentialUnavailable,
  ),
  ExchangeSessionRejectedFailure() => const ReadSessionRejected(
    ExchangeSessionRejection.server,
  ),
  ExchangeNetworkFailure(:final logMessage) => ReadUnreachable(
    logMessage ?? 'network',
    isNetwork: true,
  ),
  _ => ReadUnreachable(failure.runtimeType.toString(), isNetwork: false),
};
