import '../support/bip138_prototype_fixture.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/bullvault/data/bip138_codec.dart';
import 'package:bb_mobile/features/bullvault/data/descriptor_backup_relay_datasource.dart';
import 'package:bb_mobile/features/bullvault/data/descriptor_backup_repository_impl.dart';
import 'package:bb_mobile/features/bullvault/domain/bullvault_failure.dart';
import 'package:bb_mobile/features/bullvault/domain/entities/descriptor_backup.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final fixture = Bip138PrototypeFixture();
  final repository = DescriptorBackupRepositoryImpl(
    Bip138Codec(),
    const DescriptorBackupRelayDatasource(),
  );
  test(
    'actual BullVault policy produces exactly mobile, cold and inheritance copies',
    () {
      final result = repository.prepare(fixture.descriptor());
      expect(result, isA<Ok<DescriptorBackup, BullVaultFailure>>());
      final backup = (result as Ok<DescriptorBackup, BullVaultFailure>).value;
      expect(backup.recipients.length, 3);
      for (final signer in fixture.signers) {
        expect(
          backup.recipients.any((r) => r.key.xpub == signer.accountKey.xpub),
          isTrue,
        );
      }
      for (final recipient in backup.recipients) {
        expect(Bip138Codec().decode(backup.bytes, recipient.key.xOnly), [
          backup.descriptor,
        ]);
      }
    },
  );
  test('invalid/private/oversized policy fails before any publication', () {
    for (final value in [
      'invalid',
      'wpkh(${fixture.publishingRoot}/0/*)',
      'x' * 8193,
    ]) {
      expect(
        repository.prepare(value),
        isA<Err<DescriptorBackup, BullVaultFailure>>(),
      );
    }
  });
}
