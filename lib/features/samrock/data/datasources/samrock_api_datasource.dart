import 'dart:convert';

import 'package:bb_mobile/features/samrock/domain/entities/samrock_setup.dart';
import 'package:http/http.dart' as http;

class SamrockApiDatasource {
  final http.Client _client;

  SamrockApiDatasource({http.Client? client})
      : _client = client ?? http.Client();

  Future<SamrockSetupResponse> submitSetup({
    required SamrockSetupRequest request,
    required Map<String, dynamic> descriptorPayload,
  }) async {
    final url = Uri.parse(request.setupUrl);

    if (url.scheme != 'https') {
      throw Exception('SamRock setup requires HTTPS');
    }

    final jsonString = jsonEncode(descriptorPayload);
    final body = 'json=${Uri.encodeComponent(jsonString)}';

    final response = await _client.post(
      url,
      headers: {
        'Content-Type': 'application/x-www-form-urlencoded',
      },
      body: body,
    );

    if (response.statusCode >= 200 && response.statusCode < 300) {
      try {
        final responseBody =
            jsonDecode(response.body) as Map<String, dynamic>;
        final success = responseBody['Success'] as bool? ?? true;
        final message =
            responseBody['Message'] as String? ?? 'Setup completed';
        return SamrockSetupResponse(
          success: success,
          message: message,
          statusCode: response.statusCode,
        );
      } catch (_) {
        // If response isn't JSON, treat 2xx as success
        return SamrockSetupResponse(
          success: true,
          message: 'Setup completed successfully',
          statusCode: response.statusCode,
        );
      }
    } else {
      String message;
      try {
        final responseBody =
            jsonDecode(response.body) as Map<String, dynamic>;
        message = responseBody['Message'] as String? ??
            responseBody['Error'] as String? ??
            'Server error: ${response.statusCode}';
      } catch (_) {
        message = 'Server returned ${response.statusCode}: ${response.body}';
      }

      return SamrockSetupResponse(
        success: false,
        message: message,
        statusCode: response.statusCode,
      );
    }
  }
}
