import 'package:bb_mobile/core/exchange/data/datasources/bbx_api_datasource.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/recipients/data/models/recipient_details_model.dart';
import 'package:bb_mobile/features/recipients/data/models/sepa_virtual_payee_model.dart';
import 'package:bb_mobile/features/recipients/domain/entities/cad_biller.dart';
import 'package:bb_mobile/features/recipients/domain/entities/recipient.dart';
import 'package:bb_mobile/features/recipients/domain/entities/recipient_details.dart';
import 'package:bb_mobile/features/recipients/domain/entities/recipient_details_input.dart';
import 'package:bb_mobile/features/recipients/domain/entities/recipient_type.dart';
import 'package:bb_mobile/features/recipients/domain/recipients_failure.dart';
import 'package:bb_mobile/features/recipients/domain/repositories/recipients_repository.dart';
import 'package:bbx_api/bbx_api.dart' as bbx;
import 'package:bull_logger/bull_logger.dart';

/// [RecipientsRepository] for one environment on the shared `bbx_api` client.
class BbxApiRecipientsRepository implements RecipientsRepository {
  final BbxApiDatasource _api;

  static const _minCadBillerSearchLength = 3;

  BbxApiRecipientsRepository({required this._api});

  @override
  Future<Result<Recipient, RecipientsFailure>> saveRecipient(
    RecipientDetails recipientDetails, {
    bool isFiatRecipient = true,
    required bool isTestnet,
  }) => _guard('create fiat recipient', RecipientsSaveFailure.new, () async {
    final saved = (await _api.recipients.createRecipientFiatElement(
      RecipientDetailsModel.fromDomain(recipientDetails).toJson(),
    )).unwrap();
    return _toDomain(saved);
  });

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
        : recipientTypes.map((t) => t.value).toSet().map(_fiatType).toList();
    final hasSearch = search != null && search.isNotEmpty;
    final hasFilters = types != null || isOwner != null || hasSearch;
    final request = bbx.ListRequest<bbx.ListRecipientsFiatPayload>(
      paginator: bbx.Paginator(page: page, pageSize: pageSize),
      payload: hasFilters
          ? bbx.ListRecipientsFiatPayload(
              filters: bbx.ListRecipientsFiatFilters(
                recipientTypesFiat: types,
                isOwner: isOwner,
                search: hasSearch ? search : null,
              ),
            )
          : null,
    );

    final list = fiatOnly
        ? (await _api.recipients.listRecipientsFiat(
            request,
            expandVirtualPayees: false,
            skipInvalidElements: true,
          )).unwrap()
        : (await _api.recipients.listRecipients(
            request,
            skipInvalidElements: true,
          )).unwrap();

    final recipients = list.items
        .map((r) {
          try {
            return _toDomain(r);
          } catch (err) {
            log.warning(
              'Skipping unparseable recipient element: ${err.runtimeType}',
            );
            return null;
          }
        })
        .whereType<Recipient>()
        .expand((r) => _sepaRowsFor(r, recipientTypes))
        .toList();
    return (recipients: recipients, totalRecipients: list.totalElements);
  });

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
    () async {
      (await _api.recipients.updateMyRecipientPartial(
        bbx.UpdateMyRecipientPartialPayload.interacSecurity(
          recipientId: recipientId,
          email: email,
          securityQuestion: securityQuestion,
          securityAnswer: securityAnswer,
        ),
      )).unwrap();
    },
  );

  @override
  Future<Result<String, RecipientsFailure>> checkSinpe({
    required String phoneNumber,
    required bool isTestnet,
  }) => _guard(
    'check SINPE',
    RecipientsSinpeLookupFailure.new,
    () async =>
        (await _api.recipients.checkSinpe(phoneNumber: phoneNumber)).unwrap(),
  );

  @override
  Future<Result<List<CadBiller>, RecipientsFailure>> listCadBillers({
    required String searchTerm,
    required bool isTestnet,
  }) async {
    if (searchTerm.length < _minCadBillerSearchLength) {
      log.warning('CAD biller search shorter than $_minCadBillerSearchLength');
      return const Err(RecipientsCadBillerSearchFailure());
    }
    return _guard(
      'list CAD billers',
      RecipientsCadBillerSearchFailure.new,
      () async {
        final billers = (await _api.recipients.listApayloBillers(
          searchQuery: searchTerm,
        )).unwrap().items;
        return billers
            .map((biller) {
              final code = biller.payeeCode;
              final name = biller.payeeName;
              if (code == null || name == null) return null;
              try {
                return CadBiller.create(payeeCode: code, payeeName: name);
              } catch (err) {
                log.warning('Skipping unusable CAD biller element: $err');
                return null;
              }
            })
            .whereType<CadBiller>()
            .toList();
      },
    );
  }

  static Recipient _toDomain(bbx.Recipient r) {
    final type = r.recipientTypeFiat;
    final recipientId = r.recipientId;
    final userId = r.userId;
    final userNbr = r.userNbr;
    final createdAt = r.createdAt;
    final updatedAt = r.updatedAt;
    if (type == null ||
        recipientId == null ||
        userId == null ||
        userNbr == null ||
        createdAt == null ||
        updatedAt == null) {
      throw const FormatException('recipient without its identity fields');
    }
    return Recipient.create(
      recipientId: recipientId,
      userId: userId,
      userNbr: userNbr.toInt(),
      isArchived: r.isArchived ?? false,
      createdAt: DateTime.parse(createdAt),
      updatedAt: DateTime.parse(updatedAt),
      // The API sends `name` or `ownerName`, and `phone` or `phoneNumber`, never
      // both, so each merged value fills the field its type reads.
      details: RecipientDetailsInput(
        recipientType: RecipientType.fromValue(type),
        isOwner: r.isOwner,
        label: r.label,
        isDefault: r.isDefault,
        email: r.email,
        name: r.name,
        securityQuestion: r.securityQuestion,
        securityAnswer: r.securityAnswer,
        payeeName: r.billerPayeeName,
        payeeCode: r.billerPayeeCode,
        payeeAccountNumber: r.billerPayeeAccountNumber,
        institutionNumber: r.institutionNumber,
        transitNumber: r.transitNumber,
        accountNumber: r.accountNumber,
        defaultComment: r.defaultComment,
        iban: r.iban,
        isCorporate: r.isCorporate,
        firstname: r.firstname,
        lastname: r.lastname,
        corporateName: r.corporateName,
        virtualPayeeStatus: sepaVirtualPayeeStatusFrom(r.virtualPayee),
        clabe: r.clabe,
        institutionCode: r.institutionCode,
        phone: r.phone,
        debitcard: r.debitCard,
        ownerName: r.name,
        phoneNumber: r.phone,
        claveUniform: r.claveUniform,
        bankCode: r.bankCodeCop,
        accountType: r.accountTypeCop?.enumValue,
        bankAccount: r.bankAccountCop,
        bankName: r.bankNameCop,
        documentId: r.documentIdCop,
        documentType: r.documentTypeCop?.enumValue,
      ).toDomain(),
    );
  }

  static bbx.RecipientTypeFiat _fiatType(String value) =>
      bbx.RecipientTypeFiat.values.firstWhere(
        (t) => t.enumValue == value,
        orElse: () => throw ArgumentError.value(value, 'recipientType'),
      );

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

  /// Maps a failed call to a typed failure, logging only the error code.
  Future<Result<T, RecipientsFailure>> _guard<T>(
    String operation,
    RecipientsFailure Function([String?]) onApiFailure,
    Future<T> Function() call,
  ) async {
    try {
      return Ok(await call());
    } on BbxApiException catch (e) {
      if (e.error.isUnreachable) {
        log.warning(
          'Could not reach the API to $operation: '
          '${e.error.kind.name}',
        );
        return const Err(RecipientsNetworkFailure());
      }
      log.warning('API refused to $operation — $e');
      return Err(onApiFailure());
    } on Object catch (e, st) {
      log.warning('Failed to $operation: ${e.runtimeType}', trace: st);
      return Err(onApiFailure());
    }
  }
}
