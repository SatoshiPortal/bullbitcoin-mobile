import 'package:bb_mobile/core/storage/sqlite_database.steps.dart';
import 'package:drift/drift.dart';

/// Migration from version 13 to 14
///
/// v13 is the last released schema (v6.12.x). This step is the only hop a
/// v13 database takes to reach v14.
///
/// Changes to settings table:
/// - Adds 'hide_exchange_features' column: when set, the app hides the
///   exchange features (buy/sell/pay, exchange tab and settings) for users in
///   restricted regions, leaving only self-custodial transfer/swap. Defaults
///   to false so existing installs are unaffected.
class Schema13To14 {
  static Future<void> migrate(Migrator m, Schema14 schema14) async {
    try {
      await m.addColumn(
        schema14.settings,
        schema14.settings.hideExchangeFeatures,
      );
    } catch (e) {
      if (!e.toString().contains('duplicate column')) rethrow;
    }
  }
}
