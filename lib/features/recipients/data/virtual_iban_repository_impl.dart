import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/recipients/domain/recipients_failure.dart';
import 'package:bb_mobile/features/recipients/domain/repositories/virtual_iban_repository.dart';
import 'package:bb_mobile/features/recipients/domain/value_objects/virtual_iban_status.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:dio/dio.dart';

class VirtualIbanRepositoryImpl implements VirtualIbanRepository {
  static const _recipientsPath = '/ak/api-recipients';
  static const _apiVersion = '2.0.0';

  final Dio _mainnetApiClient;
  final Dio _testnetApiClient;

  VirtualIbanRepositoryImpl(this._mainnetApiClient, this._testnetApiClient);

  @override
  Future<Result<VirtualIbanStatus, RecipientsFailure>> getStatus({
    required bool isTestnet,
  }) async {
    try {
      final response = await _client(isTestnet).post(
        _recipientsPath,
        data: {
          'jsonrpc': '2.0',
          'id': '0',
          'method': 'listRecipientsFiat',
          'params': {
            'paginator': {'page': 1, 'pageSize': 1},
            'filters': {
              'recipientTypeFiat': ['SEPA_EUR_VIRTUAL_ACCOUNT'],
              'isOwner': true,
            },
          },
        },
        options: Options(headers: {'x-api-version': _apiVersion}),
      );
      if (response.statusCode != 200 || response.data['error'] != null) {
        throw Exception('Virtual IBAN lookup was rejected');
      }
      final result = response.data['result'] as Map<String, dynamic>?;
      final elements = result?['elements'] as List<dynamic>? ?? const [];
      if (elements.isEmpty) return const Ok(VirtualIbanStatus.absent);
      return Ok(_status(elements.first as Map<String, dynamic>));
    } on Exception catch (error, stackTrace) {
      log.severe(
        message: 'Virtual IBAN lookup failed',
        error: error,
        trace: stackTrace,
      );
      return Err(VirtualIbanFailure('$error'));
    }
  }

  @override
  Future<Result<VirtualIbanStatus, RecipientsFailure>> create({
    required bool isTestnet,
  }) async {
    try {
      final response = await _client(isTestnet).post(
        _recipientsPath,
        data: {
          'jsonrpc': '2.0',
          'id': '0',
          'method': 'createMyRecipient',
          'params': {
            'element': {'recipientType': 'FR_VIRTUAL_ACCOUNT', 'isOwner': true},
          },
        },
      );
      if (response.statusCode != 200 || response.data['error'] != null) {
        throw Exception('Virtual IBAN creation was rejected');
      }
      final element =
          response.data['result']['element'] as Map<String, dynamic>;
      return Ok(_status(element));
    } on Exception catch (error, stackTrace) {
      log.severe(
        message: 'Virtual IBAN creation failed',
        error: error,
        trace: stackTrace,
      );
      return Err(VirtualIbanFailure('$error'));
    }
  }

  Dio _client(bool isTestnet) =>
      isTestnet ? _testnetApiClient : _mainnetApiClient;

  VirtualIbanStatus _status(Map<String, dynamic> element) {
    final hasIban = (element['iban'] as String?)?.isNotEmpty == true;
    final hasBic = (element['bicCode'] as String?)?.isNotEmpty == true;
    final hasBankAddress =
        (element['bankAddress'] as String?)?.isNotEmpty == true;
    return hasIban && hasBic && hasBankAddress
        ? VirtualIbanStatus.active
        : VirtualIbanStatus.pending;
  }
}
