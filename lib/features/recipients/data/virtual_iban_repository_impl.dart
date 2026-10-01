import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/recipients/domain/entities/virtual_iban.dart';
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
  Future<Result<VirtualIban, RecipientsFailure>> getStatus({
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
        return Err(_apiFailure(response.data['error']));
      }
      final result = response.data['result'] as Map<String, dynamic>?;
      final elements = result?['elements'] as List<dynamic>? ?? const [];
      if (elements.isEmpty) return const Ok(VirtualIban.absent());
      return Ok(_toVirtualIban(elements.first as Map<String, dynamic>));
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
  Future<Result<VirtualIban, RecipientsFailure>> create({
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
        return Err(_apiFailure(response.data['error']));
      }
      final element =
          response.data['result']['element'] as Map<String, dynamic>;
      return Ok(_toVirtualIban(element));
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

  VirtualIban _toVirtualIban(Map<String, dynamic> element) {
    final iban = element['iban'] as String?;
    final bicCode = element['bicCode'] as String?;
    final bankAddress = element['bankAddress'] as String?;
    final isActive =
        iban?.isNotEmpty == true &&
        bicCode?.isNotEmpty == true &&
        bankAddress?.isNotEmpty == true;
    return VirtualIban(
      status: isActive ? VirtualIbanStatus.active : VirtualIbanStatus.pending,
      iban: iban,
      bicCode: bicCode,
      bankAddress: bankAddress,
      ibanCountry: element['ibanCountry'] as String?,
    );
  }

  RecipientsFailure _apiFailure(dynamic error) {
    final errorMap = error is Map<String, dynamic> ? error : null;
    final apiError = errorMap?['data'] is Map<String, dynamic>
        ? (errorMap!['data'] as Map<String, dynamic>)['apiError']
              as Map<String, dynamic>?
        : null;
    final code = (apiError?['code'] ?? errorMap?['code'])?.toString();
    final message =
        (apiError?['en'] ?? errorMap?['message'])?.toString() ??
        'Virtual IBAN request was rejected';
    return switch (code) {
      'ERR_RCP_PO404' => VirtualIbanNotAvailableFailure(message),
      'ERR_RCP_400' => VirtualIbanEuResidencyRequiredFailure(message),
      _ => VirtualIbanFailure(message),
    };
  }
}
