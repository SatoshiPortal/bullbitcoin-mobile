import 'dart:collection';

import 'package:bb_mobile/core/recoverbull/domain/entity/decrypted_vault.dart';
import 'package:bb_mobile/features/recoverbull/presentation/bloc.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final words = [...List.filled(11, 'abandon'), 'about'];

  test(
    'diagnostics, equality and hashing never read the secret collection',
    () {
      final first = DecryptedVault(mnemonic: _UnreadableWords());
      final second = DecryptedVault(mnemonic: _UnreadableWords());
      expect(first.toString(), contains('redacted'));
      expect(first == second, isFalse);
      expect(first.hashCode, identityHashCode(first));
      final state = RecoverBullState(
        flow: RecoverBullFlow.recoverVault,
        decryptedVault: first,
      );
      expect(state.toString(), contains('redacted'));
      expect(state == state.copyWith(decryptedVault: second), isFalse);
      expect(state.hashCode, identityHashCode(state));
    },
  );

  test(
    'decrypted backup diagnostics and equality do not traverse seed words',
    () {
      final first = DecryptedVault(mnemonic: words);
      final second = DecryptedVault(mnemonic: List.of(words));
      expect(first.toString(), isNot(contains('abandon')));
      expect(first.toString(), contains('redacted'));
      expect(
        first,
        isNot(equals(second)),
        reason: 'Private models use identity, not secret-based equality',
      );
      expect(first.hashCode, identityHashCode(first));
      // Serialization is an intentional secret-bearing operation, not a log.
      expect(DecryptedVault.fromJson(first.toJson()).mnemonic, words);
    },
  );

  test(
    'recovery state diagnostics redact the password, vault key and mnemonic',
    () {
      final state = RecoverBullState(
        flow: RecoverBullFlow.recoverVault,
        vaultPassword: 'synthetic-private-backup-password',
        vaultKey: 'synthetic-private-vault-key',
        decryptedVault: DecryptedVault(mnemonic: words),
      );
      final diagnostic = state.toString();
      expect(diagnostic, isNot(contains('synthetic-private')));
      expect(diagnostic, isNot(contains('abandon')));
      expect(diagnostic, contains('redacted'));
      final copied = state.copyWith();
      expect(
        state,
        isNot(equals(copied)),
        reason: 'State comparisons must not hash or compare secrets',
      );
      expect(state.hashCode, identityHashCode(state));
      expect(copied.vaultPassword, state.vaultPassword);
      expect(copied.vaultKey, state.vaultKey);
      expect(copied.decryptedVault, same(state.decryptedVault));
    },
  );
}

class _UnreadableWords extends ListBase<String> {
  @override
  int get length => 12;

  @override
  set length(int value) => throw UnsupportedError('immutable test words');

  @override
  String operator [](int index) => throw StateError('secret words were read');

  @override
  void operator []=(int index, String value) =>
      throw UnsupportedError('immutable test words');
}
