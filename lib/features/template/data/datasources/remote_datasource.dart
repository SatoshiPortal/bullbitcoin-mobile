import 'dart:convert';
import 'dart:io';

class RemoteDatasource {
  final HttpClient _httpClient;

  RemoteDatasource({required HttpClient httpClient}) : _httpClient = httpClient;

  Future<String> fetchIpAddress() async {
    try {
      // Make HTTP request to get IP address using ifconfig.me
      final request = await _httpClient.getUrl(
        Uri.parse('https://ifconfig.me/ip'),
      );
      final response = await request.close();

      if (response.statusCode == 200) {
        final responseBody = await response.transform(utf8.decoder).join();
        return responseBody.trim();
      } else {
        throw 'HTTP request failed with status: ${response.statusCode}';
      }
    } catch (e) {
      throw 'Failed to get IP address: $e';
    }
  }

  Future<Map<String, dynamic>> getDetailedIPInfo() async {
    try {
      // Get detailed info using ifconfig.me/all.json
      final request = await _httpClient.getUrl(
        Uri.parse('https://ifconfig.me/all.json'),
      );
      final response = await request.close();

      if (response.statusCode == 200) {
        final responseBody = await response.transform(utf8.decoder).join();
        return json.decode(responseBody) as Map<String, dynamic>;
      } else {
        throw 'HTTP request failed with status: ${response.statusCode}';
      }
    } catch (e) {
      throw 'Failed to get detailed IP info: $e';
    }
  }
}
