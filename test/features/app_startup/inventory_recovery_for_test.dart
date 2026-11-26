import 'package:bb_mobile/init.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:legacy_storage/legacy_storage.dart';
import 'package:startup/startup.dart';

void main() {
  group('inventoryRecoveryFor', () {
    test('blocks only on the wallet storage own unreadable data', () {
      const expected = {
        LegacyOwnerFailureCause.unreadable: InventoryRecoveryCause.unreadable,
        LegacyOwnerFailureCause.keyLost: InventoryRecoveryCause.keyLost,
        LegacyOwnerFailureCause.missingAfterAdmission:
            InventoryRecoveryCause.missingAfterAdmission,
      };
      for (final MapEntry(:key, :value) in expected.entries) {
        expect(
          inventoryRecoveryFor(LegacyOwnerFailure('secrets', key)),
          isA<InventoryRecoveryRequired>().having(
            (f) => f.cause,
            'cause',
            value,
          ),
        );
      }
    });

    test('a locked keystore, contention or a newer schema keep retrying', () {
      for (final cause in [
        LegacyOwnerFailureCause.keystoreLocked,
        LegacyOwnerFailureCause.contention,
        LegacyOwnerFailureCause.unsupportedSchema,
      ]) {
        expect(
          inventoryRecoveryFor(LegacyOwnerFailure('secrets', cause)),
          isNull,
        );
      }
    });

    test('another owner never leads to the wallet storage screen', () {
      for (final owner in ['signers', 'sync', 'recoverbull', 'preferences']) {
        for (final cause in LegacyOwnerFailureCause.values) {
          expect(
            inventoryRecoveryFor(LegacyOwnerFailure(owner, cause)),
            isNull,
          );
        }
      }
    });

    test('plain storage failures are not a recovery', () {
      expect(inventoryRecoveryFor(const LegacyImportUnavailable()), isNull);
      expect(inventoryRecoveryFor(const LegacyImportDeferred()), isNull);
      expect(
        inventoryRecoveryFor(const LegacyImportVerificationFailed()),
        isNull,
      );
    });
  });
}
