import 'package:exchange/src/recipients/domain/entities/cad_biller.dart';
import 'package:exchange/src/recipients/domain/entities/recipient.dart';
import 'package:exchange/src/recipients/domain/entities/recipient_details.dart';
import 'package:exchange/src/recipients/domain/entities/recipient_type.dart';
import 'package:exchange/src/domain/exchange_failure.dart';
import 'package:exchange/src/recipients/domain/repositories/recipients_repository.dart';
import 'package:exchange/src/domain/exchange_environment.dart';
import 'package:exchange/src/recipients/data/bbx_api_sepa_virtual_payee_repository.dart';
import 'package:exchange/src/recipients/domain/entities/interac_security_details.dart';
import 'package:exchange/src/recipients/domain/entities/sepa_virtual_payee_status.dart';
import 'package:exchange/src/recipients/data/bbx_api_recipients_datasource.dart';
import 'package:bbx_api/bbx_api.dart' as bbx;
import 'package:primitives/primitives.dart';

typedef RunRecipientOperation = Future<Result<T, ExchangeFailure>> Function<T>(
  ExchangeEnvironment,
  Future<Result<T, ExchangeFailure>> Function(bbx.Bbx),
);

/// [RecipientsRepository] on the `bbx_api` package: each call runs on a
/// client of the session of the environment `isTestnet` names.
final class BbxApiRecipientsRepository implements RecipientsRepository {
  final RunRecipientOperation _read;
  final RunRecipientOperation _write;

  const BbxApiRecipientsRepository({required this._read, required this._write});

  Future<Result<T, ExchangeFailure>> _execute<T>(
    RunRecipientOperation run,
    ExchangeEnvironment environment,
    Future<Result<T, ExchangeFailure>> Function(bbx.Bbx) operation,
  ) async => (await run<T>(environment, operation)).mapErr((failure) {
    return switch (failure) {
      // What the recipient calls answer themselves.
      ExchangeRecipientsLoadFailure() ||
      ExchangeRecipientsSaveFailure() ||
      ExchangeRecipientsInvalidFieldsFailure() ||
      ExchangeRecipientsSaveOutcomeUnknownFailure() ||
      ExchangeRecipientsSinpeLookupFailure() ||
      ExchangeRecipientsCadBillerSearchFailure() ||
      ExchangeRecipientsSelectionFailure() ||
      ExchangeRecipientsSavedButNotSelectedFailure() ||
      ExchangeRecipientsInvalidSecurityDetailsFailure() ||
      ExchangeNotAuthenticatedFailure() ||
      ExchangeUnsupportedNetworkFailure() ||
      ExchangeNetworkFailure() ||
      ExchangeUnexpectedFailure() ||
      ExchangeVirtualIbanNotAvailableFailure() ||
      ExchangeEuResidencyRequiredFailure() => failure,
      // A failure of the session around the call: none of the recipient
      // screens words it, so it is reported as unexpected.
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
      ExchangeOperationStaleFailure() ||
      ExchangeOrderInventoryUnavailableFailure() ||
      ExchangeCredentialReadFailure() ||
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
      ExchangeJournalFailure() ||
      ExchangeDestinationUnavailableFailure() ||
      ExchangeDestinationInvalidFailure() ||
      ExchangeFeeEstimatesUnavailableFailure() ||
      ExchangeWalletCoinsUnavailableFailure() ||
      ExchangeTransactionLookupFailure() ||
      ExchangeMissingFailure() ||
      ExchangeUnreachableFailure() ||
      ExchangeMalformedFailure() ||
      ExchangeSessionRejectedFailure() ||
      ExchangeWriteRefusedFailure() ||
      ExchangeWriteOutcomeUnknownFailure() ||
      ExchangeWriteNotSentFailure() ||
      ExchangePayinBuildFailure() => ExchangeUnexpectedFailure(
        failure.runtimeType.toString(),
      ),
    };
  });

  @override
  Future<Result<Recipient, ExchangeFailure>> saveRecipient(
    RecipientDetails details, {
    bool isFiatRecipient = true,
    required bool isTestnet,
  }) => _execute(
    _write,
    _environment(isTestnet),
    (client) => BbxApiRecipientsDatasource(api: client).saveRecipient(
      details,
      isFiatRecipient: isFiatRecipient,
      isTestnet: isTestnet,
    ),
  );

  @override
  Future<Result<RecipientPage, ExchangeFailure>> listRecipients({
    required bool isTestnet,
    bool fiatOnly = true,
    int page = 1,
    int pageSize = 50,
    List<RecipientType>? recipientTypes,
    bool? isOwner,
    String? search,
  }) => _execute(
    _read,
    _environment(isTestnet),
    (client) => BbxApiRecipientsDatasource(api: client).listRecipients(
      isTestnet: isTestnet,
      fiatOnly: fiatOnly,
      page: page,
      pageSize: pageSize,
      recipientTypes: recipientTypes,
      isOwner: isOwner,
      search: search,
    ),
  );

  @override
  Future<Result<String, ExchangeFailure>> checkSinpe({
    required String phoneNumber,
    required bool isTestnet,
  }) => _execute(
    _read,
    _environment(isTestnet),
    (client) =>
        BbxApiRecipientsDatasource(api: client)
            .checkSinpe(isTestnet: isTestnet, phoneNumber: phoneNumber),
  );

  @override
  Future<Result<List<CadBiller>, ExchangeFailure>> listCadBillers({
    required String searchTerm,
    required bool isTestnet,
  }) => _execute(
    _read,
    _environment(isTestnet),
    (client) =>
        BbxApiRecipientsDatasource(api: client)
            .listCadBillers(isTestnet: isTestnet, searchTerm: searchTerm),
  );

  @override
  Future<Result<void, ExchangeFailure>> updateInteracSecurityDetails({
    required String recipientId,
    required String email,
    required String? securityQuestion,
    required String? securityAnswer,
    required bool isTestnet,
  }) async {
    switch (InteracSecurityDetails.create(
      recipientId: recipientId,
      email: email,
      securityQuestion: securityQuestion,
      securityAnswer: securityAnswer,
    )) {
      case Err(:final failure):
        return Err(failure);
      case Ok(value: final details):
        return _execute(
          _write,
          _environment(isTestnet),
          (client) =>
              BbxApiRecipientsDatasource(api: client)
                  .updateInteracSecurityDetails(
                    isTestnet: isTestnet,
                    recipientId: details.recipientId,
                    email: details.email,
                    securityQuestion: details.securityQuestion,
                    securityAnswer: details.securityAnswer,
                  ),
        );
    }
  }

  @override
  Future<Result<SepaVirtualPayeeStatus, ExchangeFailure>> activate({
    required String recipientId,
    required bool isTestnet,
  }) => _execute(
    _write,
    _environment(isTestnet),
    (client) => BbxApiSepaVirtualPayeeRepository(
      mainnet: client,
      testnet: client,
    ).activate(recipientId: recipientId, isTestnet: isTestnet),
  );

  @override
  Future<Result<SepaVirtualPayeeStatus?, ExchangeFailure>> findStatus({
    required String recipientId,
    required bool isTestnet,
  }) => _execute(
    _read,
    _environment(isTestnet),
    (client) => BbxApiSepaVirtualPayeeRepository(
      mainnet: client,
      testnet: client,
    ).findStatus(recipientId: recipientId, isTestnet: isTestnet),
  );
}

ExchangeEnvironment _environment(bool isTestnet) =>
    isTestnet ? ExchangeEnvironment.testnet : ExchangeEnvironment.mainnet;
