import 'package:bb_mobile/main.dart';
import 'package:flutter_test/flutter_test.dart';

import 'bull_bitcoin_user_datasource_test.dart'
    as bull_bitcoin_user_datasource_test;
import 'exchange_rate_test.dart' as exchange_rate_test;
import 'payjoin_test.dart' as payjoin_test;
import 'sqlite_transactions_test.dart' as sqlite_transactions_test;
import 'sqlite_wallet_metadata_test.dart' as sqlite_wallet_metadata_test;

void main() async {
  TestWidgetsFlutterBinding.ensureInitialized();
  await Bull.init();

  group('Integration Tests Optimized for CI', () {
    exchange_rate_test.main(isInitialized: true);
    payjoin_test.main(isInitialized: true);
    sqlite_transactions_test.main(isInitialized: true);
    sqlite_wallet_metadata_test.main(isInitialized: true);
    bull_bitcoin_user_datasource_test.main(isInitialized: true);
  });
}
