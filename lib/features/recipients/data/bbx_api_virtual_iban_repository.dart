import 'package:bb_mobile/core/exchange/data/datasources/bbx_api_datasource.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/recipients/data/models/virtual_iban_model.dart';
import 'package:bb_mobile/features/recipients/domain/entities/virtual_iban.dart';
import 'package:bb_mobile/features/recipients/domain/recipients_failure.dart';
import 'package:bb_mobile/features/recipients/domain/repositories/virtual_iban_repository.dart';
import 'package:bbx_api/bbx_api.dart' as bbx;
import 'package:bull_logger/bull_logger.dart';

/// [VirtualIbanRepository] on the shared `bbx_api` client.
final class BbxApiVirtualIbanRepository implements VirtualIbanRepository {
  final BbxApiDatasource _mainnet;
  final BbxApiDatasource _testnet;

  const BbxApiVirtualIbanRepository({
    required this._mainnet,
    required this._testnet,
  });

  @override
  Future<Result<VirtualIban?, RecipientsFailure>> find({
    required bool isTestnet,
  }) async {
    try {
      // Not getVirtualIbanDetails: it does not filter on isOwner.
      final list = (await _api(isTestnet).recipients.listRecipientsFiat(
        bbx.ListRequest<bbx.ListRecipientsFiatPayload>(
          paginator: bbx.Paginator(page: 1, pageSize: 1),
          payload: bbx.ListRecipientsFiatPayload(
            filters: bbx.ListRecipientsFiatFilters(
              recipientTypesFiat: [bbx.RecipientTypeFiat.sepaEurVirtualAccount],
              isOwner: true,
            ),
          ),
        ),
        expandVirtualPayees: false,
      )).unwrap();
      if (list.items.isEmpty) return const Ok(null);
      return Ok(toModel(list.items.first).toDomain);
    } on BbxApiException catch (e, st) {
      // The API refuses to list virtual IBANs to a user who has none yet and
      // lacks the funding option, so this means "none".
      if (bbx.BBApiErrorCode.fromString(e.error.apiErrorCode) ==
          bbx.BBApiErrorCode.errRcpPo404) {
        return const Ok(null);
      }
      return Err(_failureFrom(e, st, 'find the virtual IBAN'));
    } on Object catch (e, st) {
      return Err(_failureFrom(e, st, 'find the virtual IBAN'));
    }
  }

  @override
  Future<Result<VirtualIban, RecipientsFailure>> create({
    required bool isTestnet,
  }) async {
    try {
      final recipient = (await _api(
        isTestnet,
      ).recipients.createVirtualIban()).unwrap();
      return Ok(toModel(recipient).toDomain);
    } on Object catch (e, st) {
      return Err(_failureFrom(e, st, 'create the virtual IBAN'));
    }
  }

  static VirtualIbanModel toModel(bbx.Recipient recipient) => VirtualIbanModel(
    iban: recipient.iban,
    bicCode: recipient.bicCodeFrAccount,
    bankAddress: recipient.bankAddressFrAccount,
    ibanCountry: recipient.ibanCountry,
  );

  BbxApiDatasource _api(bool isTestnet) => isTestnet ? _testnet : _mainnet;

  RecipientsFailure _failureFrom(Object e, StackTrace st, String operation) {
    if (e is BbxApiException) {
      if (e.error.isUnreachable) {
        log.warning(
          'Could not reach the API to $operation: '
          '${e.error.kind.name}',
        );
        return const RecipientsNetworkFailure();
      }
      log.warning('API refused to $operation — $e');
      return switch (bbx.BBApiErrorCode.fromString(e.error.apiErrorCode)) {
        bbx.BBApiErrorCode.errRcpPo404 =>
          const RecipientsVirtualIbanNotAvailableFailure(),
        bbx.BBApiErrorCode.errRcp400001 =>
          const RecipientsEuResidencyRequiredFailure(),
        _ => RecipientsUnexpectedFailure(e.toString()),
      };
    }
    log.warning('Failed to $operation: ${e.runtimeType}', trace: st);
    return const RecipientsUnexpectedFailure();
  }
}
