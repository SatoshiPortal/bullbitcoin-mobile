import 'dart:convert';

import 'package:bb_mobile/core/storage/migrations/hive_to_sqlite/old_storage.dart';
import 'package:bb_mobile/core/storage/migrations/hive_to_sqlite/old_storage_keys.dart';

({bool? unitInSats, String? currencyCode, bool? hideAmount, bool? isTestnet})
fetchSettings(HiveStorage hive) {
  final oldSettingsPayload = hive.getValue(StorageKeys.settings.name) ?? '{}';
  final oldCurrencyPayload = hive.getValue(StorageKeys.currency.name) ?? '{}';
  final oldNetworkPayload = hive.getValue(StorageKeys.network.name) ?? '{}';
  final oldSettings = json.decode(oldSettingsPayload) as Map<String, dynamic>;
  final oldCurrency = json.decode(oldCurrencyPayload) as Map<String, dynamic>;
  final oldNetwork = json.decode(oldNetworkPayload) as Map<String, dynamic>;

  final unitsInSats = oldCurrency['unitsInSats'] as bool?;
  final defaultFiatCurrency =
      (oldCurrency['defaultFiatCurrency'] as Map<String, dynamic>?)?['name']
          as String?;
  final privacyView = oldSettings['privacyView'] as bool?;
  final isTestnet = oldNetwork['testnet'] as bool? ?? false;

  return (
    unitInSats: unitsInSats,
    currencyCode: defaultFiatCurrency,
    hideAmount: privacyView,
    isTestnet: isTestnet,
  );
}
