import 'package:bb_mobile/core/exchange/data/datasources/bbx_api_datasource.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/recipients/data/models/sepa_virtual_payee_model.dart';
import 'package:bb_mobile/features/recipients/domain/entities/sepa_virtual_payee_status.dart';
import 'package:bb_mobile/features/recipients/domain/recipients_failure.dart';
import 'package:bb_mobile/features/recipients/domain/repositories/sepa_virtual_payee_repository.dart';
import 'package:bbx_api/bbx_api.dart' as bbx;
import 'package:bull_logger/bull_logger.dart';

/// [SepaVirtualPayeeRepository] on the shared `bbx_api` client.
final class BbxApiSepaVirtualPayeeRepository
    implements SepaVirtualPayeeRepository {
  final BbxApiDatasource _mainnet;
  final BbxApiDatasource _testnet;

  static const _pageSize = 50;
  static const _maxPages = 20;

  const BbxApiSepaVirtualPayeeRepository({
    required this._mainnet,
    required this._testnet,
  });

  @override
  Future<Result<SepaVirtualPayeeStatus, RecipientsFailure>> activate({
    required String recipientId,
    required bool isTestnet,
  }) async {
    try {
      final recipient = (await _api(
        isTestnet,
      ).recipients.activateSepaVirtualPayee(recipientId)).unwrap();
      return Ok(sepaVirtualPayeeStatusFrom(recipient.virtualPayee));
    } on Object catch (e, st) {
      return Err(
        _failureFrom(
          e,
          st,
          'activate the virtual payee',
          RecipientsUnexpectedFailure.new,
        ),
      );
    }
  }

  @override
  Future<Result<SepaVirtualPayeeStatus?, RecipientsFailure>> findStatus({
    required String recipientId,
    required bool isTestnet,
  }) async {
    try {
      final api = _api(isTestnet);
      for (var page = 1; page <= _maxPages; page++) {
        final result = (await api.recipients.listRecipientsFiat(
          bbx.ListRequest<bbx.ListRecipientsFiatPayload>(
            paginator: bbx.Paginator(page: page, pageSize: _pageSize),
            payload: bbx.ListRecipientsFiatPayload(
              filters: bbx.ListRecipientsFiatFilters(
                recipientTypesFiat: [bbx.RecipientTypeFiat.sepaEur],
              ),
            ),
          ),
          expandVirtualPayees: false,
        )).unwrap();
        for (final payee in result.items) {
          if (payee.recipientId != recipientId) continue;
          final status = sepaVirtualPayeeStatusFrom(payee.virtualPayee);
          if (status == SepaVirtualPayeeStatus.pending) {
            // Listing reads the saved status. Activation is idempotent and
            // refreshes an existing payee from Fiat Republic.
            final refreshed = (await api.recipients.activateSepaVirtualPayee(
              recipientId,
            )).unwrap();
            return Ok(sepaVirtualPayeeStatusFrom(refreshed.virtualPayee));
          }
          return Ok(status);
        }
        if (page * _pageSize >= result.totalElements) break;
      }
      return const Ok(null);
    } on Object catch (e, st) {
      return Err(
        _failureFrom(
          e,
          st,
          'read the virtual payee status',
          RecipientsLoadFailure.new,
        ),
      );
    }
  }

  BbxApiDatasource _api(bool isTestnet) => isTestnet ? _testnet : _mainnet;

  RecipientsFailure _failureFrom(
    Object e,
    StackTrace st,
    String operation,
    RecipientsFailure Function([String?]) onApiFailure,
  ) {
    if (e is BbxApiException) {
      if (e.error.isUnreachable) {
        log.warning(
          'Could not reach the API to $operation: '
          '${e.error.kind.name}',
        );
        return const RecipientsNetworkFailure();
      }
      log.warning('API refused to $operation — $e');
      return onApiFailure(e.toString());
    }
    log.warning('Failed to $operation: ${e.runtimeType}', trace: st);
    return onApiFailure();
  }
}
