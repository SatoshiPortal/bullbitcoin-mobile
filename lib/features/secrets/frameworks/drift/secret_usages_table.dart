import 'package:bb_mobile/features/secrets/interface_adapters/secret_usage/secret_usage_mappers.dart';
import 'package:drift/drift.dart';

@DataClassName('SecretUsageRow')
class SecretUsages extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get fingerprint => text()();
  TextColumn get consumerType => textEnum<SecretConsumerType>()();
  TextColumn get walletId => text().nullable()();
  TextColumn get bip85Path => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  List<Set<Column>> get uniqueKeys => [
    {
      fingerprint,
      consumerType,
      walletId,
    }, // Ensures a wallet consumer can only have one usage per fingerprint
    {
      fingerprint,
      consumerType,
      bip85Path,
    }, // Ensures a bip85 consumer can only have one usage per fingerprint
  ];

  @override
  List<String> get customConstraints => [
    r"CHECK((consumerType = 'wallet' AND walletId IS NOT NULL) OR (consumerType != 'wallet'))",
    r"CHECK((consumerType = 'bip85' AND bip85Path IS NOT NULL) OR (consumerType != 'bip85'))",
  ];
}
