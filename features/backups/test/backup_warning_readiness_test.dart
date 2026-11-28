import 'package:backups/backups.dart';
import 'package:bull_recoverbull/bull_recoverbull.dart' as rb;
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';

void main() {
  test(
    'keeps a failed readiness read distinct from ready or not needed',
    () async {
      rb.Result<bool, rb.RecoverBullFailure> result = const Ok(true);
      Future<bool?> read() =>
          BackupsFeature.readWarningNeeded(() async => result);
      expect(await read(), isTrue);
      result = const Ok(false);
      expect(await read(), isFalse);
      result = const Err(rb.VaultStorageFailure());
      expect(await read(), isNull);
    },
  );
}
