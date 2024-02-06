import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lwk_dart/lwk_dart.dart';
import 'package:path_provider/path_provider.dart';

void main() {
  test('Sample', () async {
    try {
      const mnemonic =
          'bacon bacon bacon bacon bacon bacon bacon bacon bacon bacon bacon bacon bacon bacon bacon bacon bacon bacon bacon bacon bacon bacon bacon bacon';
      const network = LiquidNetwork.Testnet;
      const electrumUrl = 'blockstream.info:465';

      Future<String> getDbDir() async {
        try {
          WidgetsFlutterBinding.ensureInitialized();
          final directory = await getApplicationDocumentsDirectory();
          final path = '${directory.path}/lwk-db';
          return path;
        } catch (e) {
          print('Error getting current directory: $e');
          rethrow;
        }
      }

      final dbPath = await getDbDir();
      final wallet = await LiquidWallet.create(
        mnemonic: mnemonic,
        network: network,
        dbPath: dbPath,
      );
      await wallet.sync(electrumUrl);
      final address = await wallet.address();
      print(address);
    } catch (e) {
      print(e);
      if (e is LwkError) {
        print(e.msg);
      }
    }
  });
}
