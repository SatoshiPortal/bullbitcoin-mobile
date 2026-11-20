import 'package:bb_mobile/core/exchange/data/exchange_authentication.dart';
import 'package:bb_mobile/features/recipients/data/models/sepa_virtual_payee_model.dart'
    show sepaVirtualPayeeStatusFromApi;
import 'package:bb_mobile/features/recipients/domain/entities/cad_biller.dart';
import 'package:bb_mobile/features/recipients/domain/entities/recipient.dart';
import 'package:bb_mobile/features/recipients/domain/entities/recipient_details.dart';
import 'package:bb_mobile/features/recipients/domain/entities/recipient_details_input.dart';
import 'package:bb_mobile/features/recipients/domain/entities/recipient_type.dart';
import 'package:bb_mobile/features/recipients/domain/recipients_failure.dart';
import 'package:bb_mobile/features/recipients/domain/repositories/recipients_repository.dart';
import 'package:bbx_api/bbx_api.dart' as bbx;
import 'package:bull_logger/bull_logger.dart';
import 'package:dio/dio.dart';
import 'package:primitives/primitives.dart';

/// [RecipientsRepository] for one environment on the `bbx_api` package.
///
/// The `isTestnet` arguments are ignored: the [bbx.BbxApiClient] is bound to
/// one environment.
class BbxApiRecipientsRepository implements RecipientsRepository {
  final bbx.BbxApiClient _api;

  BbxApiRecipientsRepository({required this._api});

  @override
  Future<Result<Recipient, RecipientsFailure>> saveRecipient(
    RecipientDetails recipientDetails, {
    bool isFiatRecipient = true,
    required bool isTestnet,
  }) => _guard(
    'create fiat recipient',
    RecipientsSaveFailure.new,
    () async => _toRecipient(
      await _api.recipients.createRecipientFiat(
        _toNewRecipient(recipientDetails),
      ),
    ),
  );

  @override
  Future<Result<void, RecipientsFailure>> updateInteracSecurityDetails({
    required String recipientId,
    required String email,
    required String? securityQuestion,
    required String? securityAnswer,
    required bool isTestnet,
  }) => _guard(
    'update Interac security details',
    RecipientsUnexpectedFailure.new,
    () => _api.recipients.updateInteracSecurityDetails(
      recipientId: recipientId,
      email: email,
      securityQuestion: securityQuestion,
      securityAnswer: securityAnswer,
    ),
  );

  @override
  Future<
    Result<
      ({List<Recipient> recipients, int totalRecipients}),
      RecipientsFailure
    >
  >
  listRecipients({
    bool fiatOnly = true,
    required bool isTestnet,
    int page = 1,
    int pageSize = 50,
    List<RecipientType>? recipientTypes,
    bool? isOwner,
    String? search,
  }) => _guard('list fiat recipients', RecipientsLoadFailure.new, () async {
    final types = recipientTypes == null || recipientTypes.isEmpty
        ? null
        : recipientTypes.map((t) => t.value).toSet().toList();
    final searchFilter = search == null || search.isEmpty ? null : search;
    final list = fiatOnly
        ? _api.recipients.listRecipientsFiat
        : _api.recipients.listRecipients;
    final result = await list(
      page: page,
      pageSize: pageSize,
      recipientTypeFiat: types,
      isOwner: isOwner,
      search: searchFilter,
    );
    _logSkipped(result.skippedElements, 'recipient');

    // A recipient this app build cannot represent must not fail the whole
    // list: dropping one row is better than showing none.
    final recipients = result.recipients
        .map((r) => _skipUnusable(() => _toRecipient(r), 'recipient'))
        .nonNulls
        .expand((r) => _sepaRowsFor(r, recipientTypes))
        .toList();
    return (
      recipients: recipients,
      totalRecipients: result.totalElements.toInt(),
    );
  });

  @override
  Future<Result<String, RecipientsFailure>> checkSinpe({
    required String phoneNumber,
    required bool isTestnet,
  }) => _guard(
    'check SINPE',
    RecipientsSinpeLookupFailure.new,
    () => _api.recipients.checkSinpe(phoneNumber: phoneNumber),
  );

  @override
  Future<Result<List<CadBiller>, RecipientsFailure>> listCadBillers({
    required String searchTerm,
    required bool isTestnet,
  }) => _guard(
    'list CAD billers',
    RecipientsCadBillerSearchFailure.new,
    () async {
      final result = await _api.recipients.listAplBillers(search: searchTerm);
      _logSkipped(result.skippedElements, 'CAD biller');
      return result.billers
          .map(
            (b) => _skipUnusable(
              () => CadBiller.create(
                payeeCode: b.payeeCode,
                payeeName: b.payeeName,
              ),
              'CAD biller',
            ),
          )
          .nonNulls
          .toList();
    },
  );

  static bbx.NewFiatRecipient _toNewRecipient(RecipientDetails d) =>
      switch (d) {
        InteracEmailCadDetails() => bbx.NewInteracEmailCadRecipient(
          label: d.label,
          isOwner: d.isOwner,
          isDefault: d.isDefault,
          email: d.email,
          name: d.name,
          securityQuestion: d.securityQuestion,
          securityAnswer: d.securityAnswer,
        ),
        BillPaymentCadDetails() => bbx.NewBillPaymentCadRecipient(
          label: d.label,
          isOwner: d.isOwner,
          isDefault: d.isDefault,
          payeeName: d.payeeName,
          payeeCode: d.payeeCode,
          payeeAccountNumber: d.payeeAccountNumber,
        ),
        BankTransferCadDetails() => bbx.NewBankTransferCadRecipient(
          label: d.label,
          isOwner: d.isOwner,
          isDefault: d.isDefault,
          name: d.name,
          institutionNumber: d.institutionNumber,
          transitNumber: d.transitNumber,
          accountNumber: d.accountNumber,
          defaultComment: d.defaultComment,
        ),
        SepaEurDetails() => bbx.NewSepaEurRecipient(
          label: d.label,
          isOwner: d.isOwner,
          isDefault: d.isDefault,
          iban: d.iban,
          isCorporate: d.isCorporate,
          firstname: d.firstname,
          lastname: d.lastname,
          corporateName: d.corporateName,
        ),
        SpeiClabeMxnDetails() => bbx.NewSpeiClabeMxnRecipient(
          label: d.label,
          isOwner: d.isOwner,
          isDefault: d.isDefault,
          name: d.name,
          clabe: d.clabe,
        ),
        SpeiSmsMxnDetails() => bbx.NewSpeiSmsMxnRecipient(
          label: d.label,
          isOwner: d.isOwner,
          isDefault: d.isDefault,
          name: d.name,
          institutionCode: d.institutionCode,
          phone: d.phone,
        ),
        SpeiCardMxnDetails() => bbx.NewSpeiCardMxnRecipient(
          label: d.label,
          isOwner: d.isOwner,
          isDefault: d.isDefault,
          name: d.name,
          institutionCode: d.institutionCode,
          debitcard: d.debitcard,
        ),
        SinpeIbanUsdDetails() => bbx.NewSinpeIbanUsdRecipient(
          label: d.label,
          isOwner: d.isOwner,
          isDefault: d.isDefault,
          iban: d.iban,
          ownerName: d.ownerName,
        ),
        SinpeIbanCrcDetails() => bbx.NewSinpeIbanCrcRecipient(
          label: d.label,
          isOwner: d.isOwner,
          isDefault: d.isDefault,
          iban: d.iban,
          ownerName: d.ownerName,
        ),
        SinpeMovilCrcDetails() => bbx.NewSinpeMovilCrcRecipient(
          label: d.label,
          isOwner: d.isOwner,
          isDefault: d.isDefault,
          phoneNumber: d.phoneNumber,
          ownerName: d.ownerName,
        ),
        BankAccountArgentinaDetails() => bbx.NewBankTransferArsRecipient(
          label: d.label,
          isOwner: d.isOwner,
          isDefault: d.isDefault,
          name: d.name,
          claveUniform: d.claveUniform,
        ),
        PseColombiaDetails() => bbx.NewPseColombiaCopRecipient(
          label: d.label,
          isOwner: d.isOwner,
          isDefault: d.isDefault,
          name: d.name,
          bankCode: d.bankCode,
          accountType: d.accountType,
          bankAccount: d.bankAccount,
          bankName: d.bankName,
          documentId: d.documentId,
          documentType: d.documentType,
        ),
        NequiColombiaDetails() => bbx.NewNequiColombiaCopRecipient(
          label: d.label,
          isOwner: d.isOwner,
          isDefault: d.isDefault,
          name: d.name,
          bankAccount: d.phoneNumber,
          documentId: d.documentId,
          documentType: d.documentType,
        ),
      };

  /// Throws [_UnusableElement] when the domain rejects the recipient.
  static Recipient _toRecipient(bbx.FiatRecipient r) => _domain(
    () => Recipient.create(
      recipientId: r.recipientId,
      userId: r.userId,
      userNbr: r.userNbr,
      isArchived: r.isArchived,
      createdAt: DateTime.parse(r.createdAt),
      updatedAt: DateTime.parse(r.updatedAt),
      details: RecipientDetailsInput(
        recipientType: RecipientType.fromValue(r.recipientTypeFiat),
        isOwner: r.isOwner,
        label: r.label,
        isDefault: r.isDefault,
        email: r.email,
        name: r.name,
        securityQuestion: r.securityQuestion,
        securityAnswer: r.securityAnswer,
        payeeName: r.payeeName,
        payeeCode: r.payeeCode,
        payeeAccountNumber: r.payeeAccountNumber,
        institutionNumber: r.institutionNumber,
        transitNumber: r.transitNumber,
        accountNumber: r.accountNumber,
        defaultComment: r.defaultComment,
        iban: r.iban,
        isCorporate: r.isCorporate,
        firstname: r.firstname,
        lastname: r.lastname,
        corporateName: r.corporateName,
        virtualPayeeStatus: sepaVirtualPayeeStatusFromApi(r.virtualPayeeStatus),
        clabe: r.clabe,
        institutionCode: r.institutionCode,
        phone: r.phone,
        debitcard: r.debitcard,
        ownerName: r.ownerName,
        phoneNumber: r.phoneNumber,
        claveUniform: r.claveUniform,
        bankCode: r.bankCode,
        accountType: r.accountType,
        bankAccount: r.bankAccount,
        bankName: r.bankName,
        documentId: r.documentId,
        documentType: r.documentType,
      ).toDomain(),
    ),
  );

  /// Runs a domain constructor. They reject invalid values with these
  /// exceptions and errors, a missing required field included.
  static T _domain<T>(T Function() create) {
    try {
      return create();
    } on _UnusableElement {
      rethrow;
    } on Exception catch (e) {
      throw _UnusableElement(e.runtimeType);
    } on ArgumentError catch (e) {
      throw _UnusableElement(e.runtimeType);
    } on StateError catch (e) {
      throw _UnusableElement(e.runtimeType);
    } on TypeError catch (e) {
      throw _UnusableElement(e.runtimeType);
    }
  }

  static T? _skipUnusable<T>(T Function() create, String element) {
    try {
      return _domain(create);
    } on _UnusableElement catch (e) {
      // warning, not severe: severe uploads to the crash reporter.
      log.warning('Skipping unparseable $element element: $e');
      return null;
    }
  }

  static void _logSkipped(int count, String element) {
    if (count == 0) return;
    log.warning('Skipping $count unparseable $element elements');
  }

  /// The API returns one SEPA recipient for both payment routes, so this
  /// decides which route its row shows:
  /// - Regular SEPA requested, or no type filter: the regular row.
  /// - Only Confidential SEPA requested: a confidential row, if the recipient
  ///   already has a virtual payee or can activate one. Otherwise, no row.
  static Iterable<Recipient> _sepaRowsFor(
    Recipient recipient,
    List<RecipientType>? requestedTypes,
  ) {
    final details = recipient.details;
    if (details is! SepaEurDetails) return [recipient];

    final wantsRegular =
        requestedTypes == null ||
        requestedTypes.isEmpty ||
        requestedTypes.contains(RecipientType.sepaEur);
    if (wantsRegular) return [recipient];

    final canBeConfidential =
        details.hasVirtualPayee || details.canActivateVirtualPayee;
    if (!canBeConfidential) return const [];
    return [recipient.withDetails(details.asConfidential())];
  }

  /// Maps a failed call to a typed failure, logging the reason without the
  /// request or response payload. [onApiFailure] builds the
  /// operation-specific failure used for anything that is not a
  /// connectivity problem.
  Future<Result<T, RecipientsFailure>> _guard<T>(
    String operation,
    RecipientsFailure Function([String?]) onApiFailure,
    Future<T> Function() call,
  ) async {
    try {
      return Ok(await call());
    } on Exception catch (e) {
      final refusal = exchangeAuthenticationException(e);
      if (refusal != null) {
        return Err(
          refusal.isUnauthenticated
              ? const RecipientsNotAuthenticatedFailure()
              : onApiFailure('Exchange credential unavailable'),
        );
      }
      switch (e) {
        case bbx.BbxApiHttpException(:final statusCode):
          log.warning('API refused to $operation — HTTP $statusCode');
          return Err(onApiFailure());
        case bbx.BbxApiRpcException(:final code):
          // The error object can quote the rejected payload: keep its code.
          log.warning(
            'API refused to $operation — '
            'JSON-RPC error code ${code ?? 'unknown'}',
          );
          return Err(onApiFailure());
        case DioException(
          type: DioExceptionType.connectionTimeout ||
              DioExceptionType.sendTimeout ||
              DioExceptionType.receiveTimeout ||
              DioExceptionType.connectionError,
        ):
          log.warning('Could not reach the API to $operation: ${e.type}');
          return const Err(RecipientsNetworkFailure());
      }
      log.warning('Failed to $operation category=${e.runtimeType}');
      return Err(onApiFailure());
    }
  }
}

/// The domain could not represent an element the API returned. Carries only
/// the type of the rejection: its message can quote banking details.
final class _UnusableElement implements Exception {
  final Type reason;

  const _UnusableElement(this.reason);

  @override
  String toString() => 'UnusableElement($reason)';
}
