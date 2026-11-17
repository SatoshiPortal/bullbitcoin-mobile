/// On-demand SQL projection of physically stored Bark material. No native calls.
library;

export 'src/domain/ark_sql_exit_repository.dart';
export 'src/domain/entities/ark_sql_exit.dart';

import 'ark.dart';
import 'src/data/bark_sql_exit_repository.dart';
import 'src/data/bark_sql_schema.dart';
import 'src/domain/ark_sql_exit_repository.dart';

/// Binds independent trusted expectations. Opens nothing until a read is called.
/// A four-byte native fingerprint is a discriminator, not authentication.
ArkSqlExitRepository createArkSqlExitRepository({
  required String databasePath,
  required ArkAccountId account,
  required String expectedNativeFingerprint,
  required String expectedServerPubkey,
}) => BarkSqlExitRepository(
  databasePath: databasePath,
  schema: BarkSqlSchema(
    account,
    expectedNativeFingerprint,
    expectedServerPubkey,
  ),
);
