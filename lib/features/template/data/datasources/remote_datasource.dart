import 'dart:convert';

import 'package:bb_mobile/features/template/data/ip_address_model.dart';
// ignore: depend_on_referenced_packages
import 'package:http/http.dart' as http;

class RemoteDatasource {
  final http.Client _httpClient;
  final Uri _apiEndpoint = Uri(
    scheme: 'https',
    host: 'ifconfig.me',
    path: '/all.json',
  );

  RemoteDatasource({http.Client? httpClient})
    : _httpClient = httpClient ?? http.Client();

  Future<IpAddressModel> fetchIpAddress() async {
    try {
      final response = await _httpClient.get(_apiEndpoint);
      if (response.statusCode == 200) {
        return IpAddressModel.fromJson(
          json.decode(response.body) as Map<String, dynamic>,
        );
      } else {
        throw 'HTTP request failed with status: ${response.statusCode}';
      }
    } catch (e) {
      throw 'Failed to get IP address: $e';
    }
  }

  Future<Map<String, dynamic>> getDetailedIPInfo() async {
    try {
      final response = await _httpClient.get(_apiEndpoint);
      if (response.statusCode == 200) {
        return json.decode(response.body) as Map<String, dynamic>;
      } else {
        throw 'HTTP request failed with status: ${response.statusCode}';
      }
    } catch (e) {
      throw 'Failed to get detailed IP info: $e';
    }
  }
}
