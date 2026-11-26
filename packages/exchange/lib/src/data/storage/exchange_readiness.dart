import 'package:legacy_storage/coordination.dart';
import 'package:legacy_storage/legacy_storage.dart';
import 'package:primitives/primitives.dart';
import 'package:sqlite3/sqlite3.dart' show SqliteException;

import 'exchange_database.dart';

const exchangeImportReceipt = 'split-v1/exchange';
const exchangeFreshReceipt = 'fresh-v1/exchange';

typedef ExchangeApiRecords = ({String? mainnet, String? testnet});

/// Both fixed rows, or null when the table does not hold exactly them.
Future<ExchangeApiRecords?> readExchangeApiRecords(
  ExchangeDatabase database,
) async {
  final rows = await database
      .customSelect(
        'SELECT environment, encoded_record '
        'FROM exchange_api_credentials ORDER BY environment',
      )
      .get();
  if (rows.length != 2 ||
      rows[0].data['environment'] != 'mainnet' ||
      rows[1].data['environment'] != 'testnet') {
    return null;
  }
  final mainnet = rows[0].data['encoded_record'];
  final testnet = rows[1].data['encoded_record'];
  if (mainnet is! String? || testnet is! String?) return null;
  return (mainnet: mainnet, testnet: testnet);
}

/// The Settings row every admitted store holds. A row that is absent, or whose
/// username or password is neither text nor NULL, is never repaired.
Future<bool> hasExchangeBasicAuthRow(ExchangeDatabase database) async {
  final rows = await database
      .customSelect(
        'SELECT username, password FROM exchange_basic_auth '
        'WHERE settings_id = 1',
      )
      .get();
  if (rows.length != 1) return false;
  final data = rows.single.data;
  return data['username'] is String? && data['password'] is String?;
}

/// One receipt and both credential tables, or a refusal. A store whose
/// receipt is missing, duplicated or unknown is never repaired or recreated.
Future<Result<OwnerReadiness, LegacyImportFailure>> readExchangeReadiness(
  ExchangeDatabase database,
) async {
  try {
    final rows = await database
        .customSelect('SELECT id FROM legacy_import_receipts')
        .get();
    if (rows.isEmpty) return const Ok(OwnerReadiness.pending);
    if (rows.length != 1 ||
        await readExchangeApiRecords(database) == null ||
        !await hasExchangeBasicAuthRow(database)) {
      return const Err(LegacyImportVerificationFailed());
    }
    return switch (rows.single.data['id']) {
      exchangeImportReceipt => const Ok(OwnerReadiness.imported),
      exchangeFreshReceipt => const Ok(OwnerReadiness.initialized),
      _ => const Err(LegacyImportVerificationFailed()),
    };
  } on SqliteException {
    return const Err(LegacyImportUnavailable());
  }
}
