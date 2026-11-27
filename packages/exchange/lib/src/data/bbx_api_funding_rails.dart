import 'package:bbx_api/bbx_api.dart' as bbx;
import 'package:bull_logger/bull_logger.dart';
import 'package:primitives/primitives.dart';

import '../domain/catalog/exchange_catalog.dart';
import '../domain/catalog/jurisdiction.dart';
import '../domain/entities/confidential_sepa_availability.dart';
import '../domain/entities/funding_institution.dart';
import '../domain/entities/user_summary.dart';
import '../domain/entities/virtual_iban.dart';
import '../domain/exchange_failure.dart';
import '../funding/funding_instructions.dart';
import '../funding/funding_request.dart';
import 'bbx_api_virtual_ibans_repository.dart';
import 'exchange_call_classifier.dart';
import 'read_user_summary.dart';

/// The funding calls on one client, as closed results. A missing field the
/// rail shows is [ExchangeMalformedFailure], never a thrown error or an empty value
/// (FUND-1).
final class BbxApiFundingRails {
  final bbx.Bbx _api;
  final Uri paymentReturnUrl;

  const BbxApiFundingRails(this._api, {required this.paymentReturnUrl});

  Future<Result<FundingAccount, ExchangeReadFailure>> account() async {
    final UserSummary user;
    switch (await readUserSummary(_api)) {
      case Ok(:final value):
        user = value;
      case Err(:final failure):
        return Err(failure);
    }
    final Result<ConfidentialSepaAvailability, ExchangeReadFailure>
    confidentialSepa = user.isEligibleForConfidentialSepa
        ? switch (await BbxApiVirtualIbansRepository.findOn(_api)) {
            Ok(value: ActiveVirtualIban()) => const Ok(
              ConfidentialSepaAvailability.ready,
            ),
            Ok() => const Ok(ConfidentialSepaAvailability.needsVirtualIban),
            Err(:final failure) => readOfFailure(failure),
          }
        : const Ok(ConfidentialSepaAvailability.unavailable);
    return switch (confidentialSepa) {
      Ok(value: final availability) => Ok(
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
      Err(:final failure) => Err(failure),
    };
  }

  Future<Result<bool, ExchangeReadFailure>> consentOnAccount() async =>
      switch (await readUserSummary(_api)) {
        Ok(:final value) => Ok(value.hasConsentedScamWarning),
        Err(:final failure) => Err(failure),
      };

  /// Only `success: true` is a consent; any other answer may or may not
  /// have recorded it, so the gate re-reads.
  Future<Result<void, ExchangeWriteFailure>> consent() async {
    switch (await _api.users.registerResponsibilityConsent()) {
      case Ok(value: true):
        return const Ok(null);
      case Ok():
        log.warning('registerResponsibilityConsent answered without success');
        return const Err(
          ExchangeWriteOutcomeUnknownFailure(
            'consent answered without success',
          ),
        );
      case Err(:final failure):
        return writeOf(failure);
    }
  }

  Future<Result<List<FundingInstitution>, ExchangeReadFailure>> institutions(
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

  Future<Result<FundingAnswer, ExchangeReadFailure>> instructions(
    FundingRequest request,
  ) => switch (request) {
    ProcessorCodeRequest() => _processorCode(request),
    CopPaymentRequest() => _copLink(request),
  };

  Future<Result<FundingAnswer, ExchangeReadFailure>> _processorCode(
    ProcessorCodeRequest request,
  ) async {
    final rail = request.rail;
    final answer = await _api.recipients.getUserPaymentProcessorCode(
      rail.paymentProcessorCode,
    );
    if (_refusal(answer) case final refusal?) {
      return Ok(FundingRefused(refusal));
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
    final bbx.PaymentProcessorDetails details;
    switch (read) {
      case Ok(:final value):
        details = value;
      case Err(:final failure):
        return Err(failure);
    }
    final rows = <InstructionRow>[];
    for (final field in rail.fields) {
      final value = _wireValue(details, field, request.userNumber);
      if (value == null || value.trim().isEmpty) {
        log.warning(
          'getUserPaymentProcessorCode: ${rail.name} answer has no '
          '${field.name}',
        );
        return Err(ExchangeMalformedFailure('missing ${field.name}'));
      }
      rows.add(InstructionRow(field, value));
    }
    return Ok(FundingInstructionsGot(rail.present(rows)));
  }

  Future<Result<FundingAnswer, ExchangeReadFailure>> _copLink(
    CopPaymentRequest request,
  ) async {
    final answer = await _api.orders.getCopPaymentLink(
      bankCode: request.institution.code,
      amount: request.amount.pesos,
      callbackUrl: paymentReturnUrl.toString(),
    );
    if (_refusal(answer) case final refusal?) {
      return Ok(FundingRefused(refusal));
    }
    final read = await exchangeRead<String, String>(
      'getCopPaymentLink',
      () async => answer,
      (link) => link,
    );
    final String answered;
    switch (read) {
      case Ok(:final value):
        answered = value;
      case Err(:final failure):
        return Err(failure);
    }
    final link = Uri.tryParse(answered.trim());
    if (link == null ||
        !(link.isScheme('https') || link.isScheme('http')) ||
        link.host.isEmpty) {
      log.warning('getCopPaymentLink answered a link that is not a web page');
      return const Err(
        ExchangeMalformedFailure('payment link is not a web page'),
      );
    }
    return Ok(FundingInstructionsGot(FundingInstructionLink(link)));
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
    int userNumber,
  ) => switch (field) {
    InstructionField.beneficiaryName => details.beneficiaryName,
    InstructionField.beneficiaryEmail => details.beneficiaryEmail,
    InstructionField.secretQuestion ||
    InstructionField.transferCode => details.code,
    InstructionField.secretAnswer => '$userNumber',
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

/// The read result of a call that failed before or around the server: the
/// session check of `withClient`, or a repository that still answers
/// [ExchangeFailure].
Result<T, ExchangeReadFailure> readOfFailure<T>(ExchangeFailure failure) =>
    switch (failure) {
      ExchangeNotAuthenticatedFailure() => const Err(
        ExchangeSessionRejectedFailure(ExchangeSessionRejection.signedOut),
      ),
      ExchangeCredentialReadFailure() => const Err(
        ExchangeSessionRejectedFailure(
          ExchangeSessionRejection.credentialUnavailable,
        ),
      ),
      ExchangeSessionRejectedFailure() => const Err(
        ExchangeSessionRejectedFailure(ExchangeSessionRejection.server),
      ),
      ExchangeNetworkFailure(:final logMessage) => Err(
        ExchangeUnreachableFailure(logMessage ?? 'network', isNetwork: true),
      ),
      // Any other failure left the read without an answer.
      ExchangeAccountUnavailableFailure() ||
      ExchangeAuthenticationDeferredFailure() ||
      ExchangeAuthenticationFailure() ||
      ExchangeApiKeyStorageFailure() ||
      ExchangeSessionClearFailure() ||
      ExchangePlatformNotAllowedFailure() ||
      ExchangePreferencesSaveFailure() ||
      ExchangePreferencesSaveOutcomeUnknownFailure() ||
      ExchangeNotificationsUnavailableFailure() ||
      ExchangeAnnouncementsUnavailableFailure() ||
      ExchangeAccountDeletionRequestFailure() ||
      ExchangeUnexpectedFailure() ||
      ExchangeOperationStaleFailure() ||
      ExchangeUnsupportedNetworkFailure() ||
      ExchangeOrderInventoryUnavailableFailure() ||
      ExchangeCredentialsUnavailableFailure() ||
      ExchangeBasicAuthSaveFailure() ||
      ExchangeApiKeyInvalidFailure() ||
      ExchangeApiKeySaveFailure() ||
      ExchangeApiKeyDeleteFailure() ||
      ExchangeOrderLimitFailure() ||
      ExchangeConfidentialSepaInactiveFailure() ||
      ExchangeOrderLoadFailure() ||
      ExchangeOrderRejectedFailure() ||
      ExchangeStatisticsUnavailableFailure() ||
      ExchangeDocumentUploadFailure() ||
      ExchangeAccountDetailsUnavailableFailure() ||
      ExchangeUploadStatusUnavailableFailure() ||
      ExchangeDocumentAlreadySubmittedFailure() ||
      ExchangeDocumentEmptyFailure() ||
      ExchangeDocumentTooLargeFailure() ||
      ExchangeDocumentTypeNotAllowedFailure() ||
      ExchangeDocumentUnreadableFailure() ||
      ExchangeWriteBusyFailure() ||
      ExchangePaymentLinkUnavailableFailure() ||
      ExchangeDefaultWalletAddressEmptyFailure() ||
      ExchangeDefaultWalletAddressInvalidFailure() ||
      ExchangeDefaultWalletSaveFailure() ||
      ExchangeDefaultWalletDeleteFailure() ||
      ExchangeConsentRegistrationFailure() ||
      ExchangeChatLoadMessagesFailure() ||
      ExchangeChatSendMessageFailure() ||
      ExchangeChatLoadAttachmentFailure() ||
      ExchangeChatNotAuthenticatedFailure() ||
      ExchangeChatMessageEmptyFailure() ||
      ExchangeChatAttachmentEmptyFailure() ||
      ExchangeChatPickImagesFailure() ||
      ExchangeChatAttachLogsFailure() ||
      ExchangeLimitOrderFailure() ||
      ExchangeFundingFailure() ||
      ExchangeVirtualIbanNotAvailableFailure() ||
      ExchangeEuResidencyRequiredFailure() ||
      ExchangeJournalFailure() ||
      ExchangeDestinationUnavailableFailure() ||
      ExchangeDestinationInvalidFailure() ||
      ExchangeMissingFailure() ||
      ExchangeUnreachableFailure() ||
      ExchangeMalformedFailure() ||
      ExchangeWriteRefusedFailure() ||
      ExchangeWriteOutcomeUnknownFailure() ||
      ExchangeWriteNotSentFailure() ||
      ExchangePayinBuildFailure() ||
      ExchangeRecipientsLoadFailure() ||
      ExchangeRecipientsSaveFailure() ||
      ExchangeRecipientsInvalidFieldsFailure() ||
      ExchangeRecipientsSaveOutcomeUnknownFailure() ||
      ExchangeRecipientsSinpeLookupFailure() ||
      ExchangeRecipientsCadBillerSearchFailure() ||
      ExchangeRecipientsSelectionFailure() ||
      ExchangeRecipientsSavedButNotSelectedFailure() ||
      ExchangeRecipientsInvalidSecurityDetailsFailure() => Err(
        ExchangeUnreachableFailure(
          failure.runtimeType.toString(),
          isNetwork: false,
        ),
      ),
    };
