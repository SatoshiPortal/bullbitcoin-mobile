import 'package:exchange/src/recipients/data/sepa_virtual_payee_status_mapper.dart';
import 'package:exchange/src/recipients/domain/entities/cad_biller.dart';
import 'package:exchange/src/recipients/domain/entities/recipient.dart';
import 'package:exchange/src/recipients/domain/entities/recipient_details.dart';
import 'package:exchange/src/recipients/domain/entities/recipient_details_input.dart';
import 'package:exchange/src/recipients/domain/entities/recipient_type.dart';
import 'package:exchange/src/data/exchange_call_classifier.dart';
import 'package:exchange/src/domain/exchange_failure.dart';
import 'package:bbx_api/bbx_api.dart' as bbx;
import 'package:bull_logger/bull_logger.dart';
import 'package:primitives/primitives.dart';

/// The recipient calls on one client, the try/catch boundary of
/// `BbxApiRecipientsRepository`. The `isTestnet` arguments are ignored: the
/// [bbx.Bbx] is bound to one environment.
final class BbxApiRecipientsDatasource {
  final bbx.Bbx _api;

  BbxApiRecipientsDatasource({required this._api});

  /// A save that may have reached the server without a readable answer, a
  /// reply that can't be mapped included, is
  /// [RecipientsSaveOutcomeUnknownFailure]: the recipient may exist.
  Future<Result<Recipient, RecipientsFailure>> saveRecipient(
    RecipientDetails recipientDetails, {
    bool isFiatRecipient = true,
    required bool isTestnet,
  }) async {
    final bbx.NewFiatRecipient request;
    try {
      request = _toNewRecipient(recipientDetails);
    } on Exception catch (e) {
      log.warning('Could not build the recipient request: ${e.runtimeType}');
      return const Err(RecipientsSaveFailure());
    }
    return switch (await exchangeWrite<bbx.FiatRecipient, Recipient>(
      'create fiat recipient',
      () => _api.recipients.createRecipientFiat(request),
      _toRecipient,
    )) {
      Ok(:final value) => Ok(value),
      Err(failure: ExchangeWriteRefusedFailure(:final reason)) => Err(
        RecipientsInvalidFieldsFailure.fromFieldErrors(reason.fieldErrors) ??
            const RecipientsSaveFailure(),
      ),
      Err(
        failure: ExchangeWriteNotSentFailure(
          reason: ExchangeNotSentReason.signedOut,
        ),
      ) ||
      Err(
        failure: ExchangeSessionRejectedFailure(),
      ) => const Err(RecipientsNotAuthenticatedFailure()),
      Err(
        failure: ExchangeWriteNotSentFailure(
          reason: ExchangeNotSentReason.unreachable,
        ),
      ) =>
        const Err(RecipientsNetworkFailure()),
      Err(failure: ExchangeWriteNotSentFailure(:final reason)) => Err(
        RecipientsSaveFailure('not sent: ${reason.name}'),
      ),
      Err(failure: ExchangeWriteOutcomeUnknownFailure(:final reason)) => Err(
        RecipientsSaveOutcomeUnknownFailure(reason),
      ),
    };
  }

  Future<Result<void, RecipientsFailure>> updateInteracSecurityDetails({
    required String recipientId,
    required String email,
    required String? securityQuestion,
    required String? securityAnswer,
    required bool isTestnet,
  }) => _guard(
    'update Interac security details',
    RecipientsUnexpectedFailure.new,
    () async =>
        (await _api.recipients.updateInteracSecurityDetails(
              recipientId: recipientId,
              email: email,
              securityQuestion: securityQuestion,
              securityAnswer: securityAnswer,
            ))
            .map<void>((_) {})
            .mapErr(
              (failure) => _failure(
                failure,
                'update Interac security details',
                RecipientsUnexpectedFailure.new,
              ),
            ),
  );

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
    return result
        .map((page) => _recipientsPage(page, recipientTypes))
        .mapErr(
          (failure) => _failure(
            failure,
            'list fiat recipients',
            RecipientsLoadFailure.new,
          ),
        );
  });

  Future<Result<String, RecipientsFailure>> checkSinpe({
    required String phoneNumber,
    required bool isTestnet,
  }) => _guard(
    'check SINPE',
    RecipientsSinpeLookupFailure.new,
    () async => (await _api.recipients.checkSinpe(phoneNumber: phoneNumber))
        .mapErr(
          (failure) => _failure(
            failure,
            'check SINPE',
            RecipientsSinpeLookupFailure.new,
          ),
        ),
  );

  Future<Result<List<CadBiller>, RecipientsFailure>> listCadBillers({
    required String searchTerm,
    required bool isTestnet,
  }) => _guard(
    'list CAD billers',
    RecipientsCadBillerSearchFailure.new,
    () async {
      final result = await _api.recipients.listAplBillers(search: searchTerm);
      return result
          .map(_cadBillers)
          .mapErr(
            (failure) => _failure(
              failure,
              'list CAD billers',
              RecipientsCadBillerSearchFailure.new,
            ),
          );
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
          holder: _copHolder(d.payee),
          email: _copContact(d.payee).email,
          bankCode: d.bankCode,
          accountType: d.accountType,
          bankAccount: d.bankAccount,
          documentId: d.documentId,
          documentType: d.documentType,
        ),
        NequiColombiaDetails() => bbx.NewNequiColombiaCopRecipient(
          label: d.label,
          isOwner: d.isOwner,
          isDefault: d.isDefault,
          holder: _copHolder(d.payee),
          email: _copContact(d.payee).email,
          bankAccount: d.phoneNumber,
          documentId: d.documentId,
          documentType: d.documentType,
        ),
      };

  /// The contact a Colombian recipient is created with. A [ColombiaNameOnly]
  /// payee only comes from the server, so it is never sent back to create.
  static ColombiaContact _copContact(ColombiaPayee payee) => switch (payee) {
    final ColombiaContact contact => contact,
    ColombiaNameOnly() => throw const _NotCreatable('Colombian recipient'),
  };

  static bbx.NewCopHolder _copHolder(ColombiaPayee payee) =>
      switch (_copContact(payee).holder) {
        ColombiaIndividual(:final firstName, :final lastName) =>
          bbx.NewCopIndividual(name: firstName, lastname: lastName),
        ColombiaCorporate(:final corporateName) => bbx.NewCopCorporate(
          corporateName: corporateName,
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
      ).toStoredDomain(),
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

  /// The recipients of [page], dropping the rows this build cannot represent.
  static ({List<Recipient> recipients, int totalRecipients}) _recipientsPage(
    bbx.FiatRecipientPage page,
    List<RecipientType>? recipientTypes,
  ) {
    _logSkipped(page.skippedElements, 'recipient');

    // A recipient this app build cannot represent must not fail the whole
    // list: dropping one row is better than showing none.
    final recipients = page.recipients
        .map((r) => _skipUnusable(() => _toRecipient(r), 'recipient'))
        .nonNulls
        .expand((r) => _sepaRowsFor(r, recipientTypes))
        .toList();
    return (
      recipients: recipients,
      totalRecipients: page.totalElements.toInt(),
    );
  }

  /// The CAD billers of [result], dropping the rows this build cannot
  /// represent.
  static List<CadBiller> _cadBillers(bbx.CadBillerSearch result) {
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

  /// Runs [call] and turns a domain-mapping exception into the operation
  /// failure, logging only its type: its message can quote banking details.
  /// An API failure is mapped by [_failure] inside [call].
  Future<Result<T, RecipientsFailure>> _guard<T>(
    String operation,
    RecipientsFailure Function([String?]) onApiFailure,
    Future<Result<T, RecipientsFailure>> Function() call,
  ) async {
    try {
      return await call();
    } on Exception catch (e) {
      log.warning('Failed to $operation category=${e.runtimeType}');
      return Err(onApiFailure());
    }
  }

  /// The failure for a failed call. A missing credential and an unreadable
  /// one stay distinct, and an unreachable API keeps its own variant;
  /// everything else is the operation's failure.
  static RecipientsFailure _failure(
    bbx.BbxFailure failure,
    String operation,
    RecipientsFailure Function([String?]) onApiFailure,
  ) {
    switch (failure) {
      case bbx.BbxMissingCredentialFailure():
        return const RecipientsNotAuthenticatedFailure();
      case bbx.BbxCredentialUnavailableFailure():
        return onApiFailure('Exchange credential unavailable');
      case bbx.BbxHttpFailure() || bbx.BbxRpcFailure():
        log.warning('API refused to $operation — $failure');
        return onApiFailure();
      case bbx.BbxTimeoutFailure(:final kind):
        log.warning(
          'Could not reach the API to $operation: ${_timeoutName(kind)}',
        );
        return const RecipientsNetworkFailure();
      case bbx.BbxConnectionFailure():
        log.warning('Could not reach the API to $operation: connectionError');
        return const RecipientsNetworkFailure();
      case bbx.BbxOrderLimitFailure() ||
          bbx.BbxConfidentialSepaInactiveFailure() ||
          bbx.BbxBadCertificateFailure() ||
          bbx.BbxRequestCancelledFailure() ||
          bbx.BbxTransformTimeoutFailure() ||
          bbx.BbxTransportFailure() ||
          bbx.BbxOutcomeUnknownFailure() ||
          bbx.BbxResponseFormatFailure():
        log.warning('Failed to $operation — $failure');
        return onApiFailure();
    }
  }

  static String _timeoutName(bbx.BbxTimeoutKind kind) => switch (kind) {
    bbx.BbxTimeoutKind.connect => 'connectionTimeout',
    bbx.BbxTimeoutKind.send => 'sendTimeout',
    bbx.BbxTimeoutKind.receive => 'receiveTimeout',
  };
}

/// A recipient that can't be sent to create one: it came from the server
/// without a field the API now requires.
final class _NotCreatable implements Exception {
  final String what;

  const _NotCreatable(this.what);

  @override
  String toString() => 'NotCreatable($what)';
}

/// The domain could not represent an element the API returned. Carries only
/// the type of the rejection: its message can quote banking details.
final class _UnusableElement implements Exception {
  final Type reason;

  const _UnusableElement(this.reason);

  @override
  String toString() => 'UnusableElement($reason)';
}
