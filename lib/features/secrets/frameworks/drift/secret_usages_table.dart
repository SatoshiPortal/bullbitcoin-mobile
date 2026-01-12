import 'package:bb_mobile/core/primitives/secrets/secret_usage_purpose.dart';
import 'package:drift/drift.dart';

@DataClassName('SecretUsageRow')
class SecretUsages extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get fingerprint => text()();
  TextColumn get purpose => textEnum<SecretUsagePurpose>()();
  TextColumn get consumerRef => text()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  List<Set<Column>> get uniqueKeys => [
    {
      purpose,
      consumerRef,
    }, // Ensures (purpose, consumerRef) combination is unique
  ];
}
