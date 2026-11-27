import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:legacy_storage/coordination.dart';
import 'package:legacy_storage/legacy_storage.dart';
import 'package:primitives/primitives.dart';
import 'package:secrets/migration.dart';

import 'support/view_fixture.dart';

/// A valid terminal receipt says the data was imported. It does not say the
/// layout of the views is one this build reads.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ViewFixture fixture;

  setUp(() async {
    fixture = await ViewFixture.create();
    await fixture.sql([
      "INSERT INTO views (id, name, background_enabled) VALUES ('b', 'B', 1)",
    ]);
  });

  tearDown(() async => fixture.close());

  test('a receipt over an unsupported layout is not admitted', () async {
    final readiness = await SecretsImport(file: fixture.file)
        .inspect(fixture.admission);
    expect(readiness, isA<Err<OwnerReadiness, LegacyImportFailure>>());
    expect(
      (readiness as Err).failure,
      isNot(isA<LegacyOwnerFailure>()),
      reason: 'never the unreadable data of a recovery',
    );
  });

  test('a replay of the initialisation does not accept it either', () async {
    await fixture.admission.close();
    final gate = NativeFileGate(File('${fixture.directory.path}/gate'));
    final exclusive = await gate.acquire(
      exclusive: true,
      timeout: Duration.zero,
    ) as ExclusiveAdmission;
    try {
      final prepared = await SecretsImport(file: fixture.file)
          .prepare(exclusive, OwnerOrigin.fresh);
      final owner = (prepared as Ok<PreparedOwner, LegacyImportFailure>).value;
      expect(await owner.initializeFresh(), isA<Err>());
      expect(await owner.receipt(), isA<Err>());
      expect(await owner.close(), isA<Ok>());
      expect(
        await SecretsRetirement(file: fixture.file).verifyRetirable(
          exclusive,
          origin: OwnerOrigin.fresh,
          source: LegacySource(File('${fixture.directory.path}/none'), 16),
        ),
        isA<Err>(),
        reason: 'the retirement gate checks the layout too',
      );
    } finally {
      await exclusive.close();
    }
  });
}
