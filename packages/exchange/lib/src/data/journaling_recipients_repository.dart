import 'package:primitives/primitives.dart';

import '../domain/exchange_environment.dart';
import '../domain/exchange_failure.dart';
import '../domain/unknown_write_journal.dart';
import '../recipients/domain/entities/cad_biller.dart';
import '../recipients/domain/entities/recipient.dart';
import '../recipients/domain/entities/recipient_details.dart';
import '../recipients/domain/entities/recipient_type.dart';
import '../recipients/domain/entities/sepa_virtual_payee_status.dart';
import '../recipients/domain/recipient_identity.dart';
import '../recipients/domain/repositories/recipients_repository.dart';
import 'journaling_orders_repository.dart';

/// [RecipientsRepository] whose recipient create is journaled when its outcome
/// is unknown. Everything else is passed through.
final class JournalingRecipientsRepository implements RecipientsRepository {
  final RecipientsRepository _recipients;
  final UnknownWriteRecorder _recorder;
  final Future<int?> Function(ExchangeEnvironment) _readEpoch;

  const JournalingRecipientsRepository(
    this._recipients,
    this._recorder, {
    required this._readEpoch,
  });

  @override
  Future<Result<Recipient, RecipientsFailure>> saveRecipient(
    RecipientDetails details, {
    bool isFiatRecipient = true,
    required bool isTestnet,
  }) async {
    final result = await _recipients.saveRecipient(
      details,
      isFiatRecipient: isFiatRecipient,
      isTestnet: isTestnet,
    );
    if (result case Err(failure: RecipientsSaveOutcomeUnknownFailure())) {
      final environment = isTestnet
          ? ExchangeEnvironment.testnet
          : ExchangeEnvironment.mainnet;
      await _recorder.record(
        UnknownWriteDraft(
          kind: UnknownWriteKind.recipientCreate,
          environment: environment,
          sessionEpoch: await _readEpoch(environment),
          request: recipientIdentity(details),
        ),
      );
    }
    return result;
  }

  @override
  Future<Result<RecipientPage, RecipientsFailure>> listRecipients({
    required bool isTestnet,
    bool fiatOnly = true,
    int page = 1,
    int pageSize = 50,
    List<RecipientType>? recipientTypes,
    bool? isOwner,
    String? search,
  }) => _recipients.listRecipients(
    isTestnet: isTestnet,
    fiatOnly: fiatOnly,
    page: page,
    pageSize: pageSize,
    recipientTypes: recipientTypes,
    isOwner: isOwner,
    search: search,
  );

  @override
  Future<Result<String, RecipientsFailure>> checkSinpe({
    required String phoneNumber,
    required bool isTestnet,
  }) => _recipients.checkSinpe(phoneNumber: phoneNumber, isTestnet: isTestnet);

  @override
  Future<Result<List<CadBiller>, RecipientsFailure>> listCadBillers({
    required String searchTerm,
    required bool isTestnet,
  }) =>
      _recipients.listCadBillers(searchTerm: searchTerm, isTestnet: isTestnet);

  @override
  Future<Result<void, RecipientsFailure>> updateInteracSecurityDetails({
    required String recipientId,
    required String email,
    required String? securityQuestion,
    required String? securityAnswer,
    required bool isTestnet,
  }) => _recipients.updateInteracSecurityDetails(
    recipientId: recipientId,
    email: email,
    securityQuestion: securityQuestion,
    securityAnswer: securityAnswer,
    isTestnet: isTestnet,
  );

  @override
  Future<Result<SepaVirtualPayeeStatus, RecipientsFailure>> activate({
    required String recipientId,
    required bool isTestnet,
  }) => _recipients.activate(recipientId: recipientId, isTestnet: isTestnet);

  @override
  Future<Result<SepaVirtualPayeeStatus?, RecipientsFailure>> findStatus({
    required String recipientId,
    required bool isTestnet,
  }) => _recipients.findStatus(recipientId: recipientId, isTestnet: isTestnet);
}
