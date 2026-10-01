import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/recipients/domain/entities/recipient.dart';
import 'package:bb_mobile/features/recipients/domain/recipients_failure.dart';
import 'package:bb_mobile/features/recipients/domain/repositories/sepa_virtual_payee_repository.dart';
import 'package:bb_mobile/features/recipients/domain/value_objects/recipient_details.dart';
import 'package:bb_mobile/features/recipients/data/models/recipient_model.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:dio/dio.dart';

class SepaVirtualPayeeRepositoryImpl implements SepaVirtualPayeeRepository {
  final Dio _mainnetApiClient;
  final Dio _testnetApiClient;

  static const _recipientsPath = '/ak/api-recipients';
  static const _apiVersion = '2.0.0';

  SepaVirtualPayeeRepositoryImpl(
    this._mainnetApiClient,
    this._testnetApiClient,
  );

  @override
  Future<Result<Recipient, RecipientsFailure>> activate({
    required String recipientId,
    required bool isTestnet,
  }) async {
    try {
      final response = await _client(isTestnet).post(
        _recipientsPath,
        data: {
          'jsonrpc': '2.0',
          'id': '0',
          'method': 'activateSepaVirtualPayee',
          'params': {'recipientId': recipientId},
        },
        options: Options(headers: {'x-api-version': _apiVersion}),
      );
      if (response.statusCode != 200 || response.data['error'] != null) {
        log.info('Virtual payee activation was rejected by the API');
        return const Err(
          RecipientActivationFailure('Virtual payee activation was rejected'),
        );
      }

      final result = response.data['result']['element'] as Map<String, dynamic>;
      return Ok(RecipientModel.fromJson(result).toDomain);
    } on Exception catch (error, stackTrace) {
      log.severe(
        message: 'Virtual payee activation failed',
        error: error,
        trace: stackTrace,
      );
      return Err(RecipientActivationFailure('$error'));
    }
  }

  @override
  Future<Result<Recipient?, RecipientsFailure>> find({
    required String recipientId,
    required bool isTestnet,
  }) async {
    const pageSize = 50;
    const maxPages = 20;
    try {
      for (var page = 1; page <= maxPages; page++) {
        final response = await _client(isTestnet).post(
          _recipientsPath,
          data: {
            'jsonrpc': '2.0',
            'id': '0',
            'method': 'listRecipientsFiat',
            'params': {
              'paginator': {'page': page, 'pageSize': pageSize},
              'filters': {
                'recipientTypeFiat': ['SEPA_EUR'],
                'isOwner': true,
              },
            },
          },
          options: Options(headers: {'x-api-version': _apiVersion}),
        );
        if (response.statusCode != 200 || response.data['error'] != null) {
          throw Exception('Virtual payee refresh was rejected');
        }

        final result = response.data['result'] as Map<String, dynamic>?;
        if (result == null) throw Exception('Virtual payee result is missing');
        final elements = result['elements'] as List<dynamic>? ?? const [];
        for (final element in elements) {
          final recipient = RecipientModel.fromJson(
            element as Map<String, dynamic>,
          ).toDomain;
          if (recipient.recipientId == recipientId) {
            return Ok(_asConfidential(recipient));
          }
        }

        final total = result['totalElements'];
        if (total is! num || page * pageSize >= total.toInt()) break;
      }
      return const Ok(null);
    } on Exception catch (error, stackTrace) {
      log.severe(
        message: 'Virtual payee status refresh failed',
        error: error,
        trace: stackTrace,
      );
      return Err(RecipientRefreshFailure('$error'));
    }
  }

  Dio _client(bool isTestnet) =>
      isTestnet ? _testnetApiClient : _mainnetApiClient;

  Recipient _asConfidential(Recipient recipient) {
    final details = recipient.details;
    if (details is! SepaEurDetails) return recipient;
    return Recipient.create(
      recipientId: recipient.recipientId,
      userId: recipient.userId,
      userNbr: recipient.userNbr,
      isArchived: recipient.isArchived,
      createdAt: recipient.createdAt,
      updatedAt: recipient.updatedAt,
      details: details.asConfidential(),
    );
  }
}
