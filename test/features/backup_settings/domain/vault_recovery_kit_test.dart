import 'dart:io';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/backup_settings/data/vault_recovery_kit_repository_impl.dart';
import 'package:bb_mobile/features/backup_settings/domain/backup_settings_failure.dart';
import 'package:bb_mobile/features/backup_settings/domain/vault_recovery_kit.dart';
import 'package:bb_mobile/features/bullvault/domain/entities/bullvault_protection.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import '../../bullvault/bullvault_test_fixture.dart';
import 'package:bb_mobile/generated/l10n/localization_en.dart';

class _Assets extends CachingAssetBundle {
  @override
  Future<ByteData> load(String key) async =>
      ByteData.sublistView(await File(key).readAsBytes());
}

void main() {
  final policy = testBullVaultRecoveryPackage(includesInheritance: true).policy;
  final repository = VaultRecoveryKitRepositoryImpl(assets: _Assets());
  final copy = VaultRecoveryKitCopy(
    title: 'Inheritance Kit',
    instructions: AppLocalizationsEn().bullVaultKitRecoveryInstructions,
    words: 'Write seed words by hand',
    passphrase: 'Passphrase (optional)',
    dates: 'Exact recovery dates (UTC)',
    descriptor: 'Complete descriptor',
    joinLines: 'Join wrapped lines without spaces.',
    footer:
        '${AppLocalizationsEn().bullVaultKitManualDetails}\n\n${AppLocalizationsEn().bullVaultKitTiming}',
    schedule: {
      policy.inheritanceActivationTimestamp!: 'Inheritance alone',
      policy.coldActivationTimestamp!: 'Cold alone',
    },
  );

  test(
    'all three kits produce a local PDF without retrieving private keys',
    () async {
      for (final kind in [
        VaultRecoveryKitKind.mobile,
        VaultRecoveryKitKind.cold,
        VaultRecoveryKitKind.inheritance,
      ]) {
        final result = await repository.create(
          VaultRecoveryKit(
            policy: policy,
            walletId: 'fixture-vault-id',
            kind: kind,
            wordCount: 12,
            message: kind == VaultRecoveryKitKind.inheritance
                ? 'For our children.'
                : '',
          ),
          copy,
        );
        expect(result, isA<Ok<Uint8List, BackupSettingsFailure>>());
        final bytes = (result as Ok<Uint8List, BackupSettingsFailure>).value;
        expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
        expect(bytes.length, greaterThan(10000));
        // Optional artifact for visual/QR review; never a real seed or descriptor.
        const artifacts = String.fromEnvironment('BULLVAULT_KIT_TEST_OUTPUT');
        if (artifacts.isNotEmpty) {
          await File('$artifacts/${kind.name}.pdf').writeAsBytes(bytes);
        }
      }
    },
  );

  test(
    'large policy, 24 words and a full personal message paginate successfully',
    () async {
      final extraPolicy = testBullVaultRecoveryPackage(
        includesInheritance: true,
        protection: BullVaultProtection.extra,
      ).policy;
      final result = await repository.create(
        VaultRecoveryKit(
          policy: extraPolicy,
          walletId: 'fixture-large-vault',
          kind: VaultRecoveryKitKind.inheritance,
          wordCount: 24,
          message: 'A personal message for the family. ' * 34,
        ),
        copy,
      );
      expect(result, isA<Ok<Uint8List, BackupSettingsFailure>>());
      const artifacts = String.fromEnvironment('BULLVAULT_KIT_TEST_OUTPUT');
      if (artifacts.isNotEmpty) {
        final bytes = (result as Ok<Uint8List, BackupSettingsFailure>).value;
        await File('$artifacts/large-inheritance.pdf').writeAsBytes(bytes);
      }
    },
  );

  test(
    'rejects nonexistent kit roles, invalid word count and oversized message',
    () async {
      for (final kit in [
        VaultRecoveryKit(
          policy: policy,
          walletId: 'fixture-vault-id',
          kind: VaultRecoveryKitKind.secondCold,
          wordCount: 12,
          message: '',
        ),
        VaultRecoveryKit(
          policy: policy,
          walletId: 'fixture-vault-id',
          kind: VaultRecoveryKitKind.mobile,
          wordCount: 13,
          message: '',
        ),
        VaultRecoveryKit(
          policy: policy,
          walletId: 'fixture-vault-id',
          kind: VaultRecoveryKitKind.inheritance,
          wordCount: 12,
          message: 'a' * 1201,
        ),
      ]) {
        expect(await repository.create(kit, copy), isA<Err>());
      }
    },
  );
}
