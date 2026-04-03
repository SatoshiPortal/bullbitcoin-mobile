import 'package:freezed_annotation/freezed_annotation.dart';

part 'samrock_setup.freezed.dart';

enum SamrockPaymentMethod {
  btc,
  lbtc,
  btcln;

  factory SamrockPaymentMethod.fromString(String value) {
    switch (value.toLowerCase()) {
      case 'btc':
      case 'btc-chain':
        return SamrockPaymentMethod.btc;
      case 'lbtc':
      case 'liquid-chain':
        return SamrockPaymentMethod.lbtc;
      case 'btcln':
      case 'btc-ln':
        return SamrockPaymentMethod.btcln;
      default:
        throw ArgumentError('Unknown payment method: $value');
    }
  }

  String get displayName {
    switch (this) {
      case SamrockPaymentMethod.btc:
        return 'Bitcoin On-chain';
      case SamrockPaymentMethod.lbtc:
        return 'Liquid';
      case SamrockPaymentMethod.btcln:
        return 'Lightning (via Boltz)';
    }
  }
}

@freezed
abstract class SamrockSetupRequest with _$SamrockSetupRequest {
  const factory SamrockSetupRequest({
    required String serverUrl,
    required String storeId,
    required List<SamrockPaymentMethod> paymentMethods,
    required String otp,
  }) = _SamrockSetupRequest;

  const SamrockSetupRequest._();

  String get setupUrl =>
      '$serverUrl/plugins/$storeId/samrock/protocol?setup=${paymentMethods.map((m) => m.name).join(',')}&otp=$otp';

  String get serverHost => Uri.parse(serverUrl).host;

  static SamrockSetupRequest? tryParse(String url) {
    try {
      final uri = Uri.parse(url);

      if (uri.scheme != 'https') return null;

      // Match path: /plugins/<storeId>/samrock/protocol
      final pathSegments = uri.pathSegments;
      if (pathSegments.length < 4) return null;

      final pluginsIndex = pathSegments.indexOf('plugins');
      if (pluginsIndex == -1) return null;
      if (pluginsIndex + 3 >= pathSegments.length) return null;
      if (pathSegments[pluginsIndex + 2] != 'samrock') return null;
      if (pathSegments[pluginsIndex + 3] != 'protocol') return null;

      final storeId = pathSegments[pluginsIndex + 1];

      final setupParam = uri.queryParameters['setup'];
      final otp = uri.queryParameters['otp'];

      if (setupParam == null || setupParam.isEmpty) return null;
      if (otp == null || otp.isEmpty) return null;

      final methods = setupParam
          .split(',')
          .map((m) => m.trim())
          .where((m) => m.isNotEmpty)
          .map(SamrockPaymentMethod.fromString)
          .toList();

      if (methods.isEmpty) return null;

      final serverUrl = '${uri.scheme}://${uri.host}${uri.hasPort ? ':${uri.port}' : ''}';

      return SamrockSetupRequest(
        serverUrl: serverUrl,
        storeId: storeId,
        paymentMethods: methods,
        otp: otp,
      );
    } catch (_) {
      return null;
    }
  }
}

@freezed
abstract class SamrockSetupResponse with _$SamrockSetupResponse {
  const factory SamrockSetupResponse({
    required bool success,
    @Default('') String message,
    @Default(0) int statusCode,
  }) = _SamrockSetupResponse;
}
