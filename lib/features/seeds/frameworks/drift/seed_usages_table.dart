import 'package:bb_mobile/core/primitives/seeds/seed_usage_purpose.dart';
import 'package:drift/drift.dart';

@DataClassName('SeedUsageRow')
class SeedUsages extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get fingerprint => text()();
  TextColumn get purpose => textEnum<SeedUsagePurpose>()();
  TextColumn get consumerRef => text()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}
