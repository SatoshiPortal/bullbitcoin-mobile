import 'package:bb_mobile/_pkg/consts/configs.dart';
import 'package:bb_mobile/_pkg/error.dart';
import 'package:dio/dio.dart';

class MempoolAPI {
  MempoolAPI(this.http);

  final Dio http;

  // Future<(List<int>?, Err?)>

  Result<List<int>> getFees(bool isTestnet) async {
    try {
      final testnet = isTestnet ? '/testnet' : '';
      final url = 'https://$mempoolapi$testnet/api/v1/fees/recommended';
      final resp = await http.get(url);
      if (resp.statusCode == null || resp.statusCode != 200) {
        throw 'Error Occured.';
      }
      final data = resp.data as Map<String, dynamic>;

      final fastestFee = data['fastestFee'] as int;
      final halfHourFee = data['halfHourFee'] as int;
      final hourFee = data['hourFee'] as int;
      final economyFee = data['economyFee'] as int;
      final minimumFee = data['minimumFee'] as int;

      return (
        [
          fastestFee,
          halfHourFee,
          hourFee,
          economyFee,
          minimumFee,
        ],
        null,
      );
    } catch (e) {
      return (null, Err(e.toString()));
    }
  }

  Future<(List<String>?, Err?)> getVinAddressesFromTx(String txid, bool isTestnet) async {
    try {
      final testnet = isTestnet ? '/testnet' : '';
      final url = 'https://$mempoolapi$testnet/api/tx/$txid';
      final resp = await http.get(url);
      if (resp.statusCode == null || resp.statusCode != 200) {
        throw 'Error Occured.';
      }
      final data = resp.data as Map<String, dynamic>;
      final inputs = data['in'] as List<dynamic>;
      final addresses = inputs.map((e) => e['scriptpubkey_address'] as String).toList();

      return (addresses, null);
    } catch (e) {
      return (null, Err(e.toString()));
    }
  }
}
