import 'package:flutter_test/flutter_test.dart';
import 'package:physical_backup_verification/src/physical_backup_session.dart';

void main() {
  test('word verdict reports only once', () {
    final session = PhysicalBackupSession();
    expect(session.wordsSolved(0, hasPassphrase: false), isTrue);
    expect(session.phase, PhysicalBackupPhase.reported);
    expect(session.wordsSolved(0, hasPassphrase: false), isFalse);
  });

  test('passphrase verification is single flight and can retry', () {
    final session = PhysicalBackupSession();
    expect(session.wordsSolved(0, hasPassphrase: true), isFalse);
    expect(session.phase, PhysicalBackupPhase.passphrase);
    expect(session.beginVerification(), isTrue);
    expect(session.beginVerification(), isFalse);
    expect(session.acceptsVerification(0), isTrue);
    session.finishVerification(verified: false);
    expect(session.phase, PhysicalBackupPhase.passphrase);
    expect(session.beginVerification(), isTrue);
    session.finishVerification(verified: true);
    expect(session.phase, PhysicalBackupPhase.reported);
    expect(session.beginVerification(), isFalse);
  });

  test('background invalidates word callbacks and resets progress', () {
    final session = PhysicalBackupSession()
      ..placed = 3
      ..total = 12;
    session.setForeground(false);
    session.setForeground(true);
    expect(session.acceptsWords(0), isFalse);
    expect(session.wordsSolved(0, hasPassphrase: false), isFalse);
    expect(session.placed, 0);
    expect(session.total, 0);
    expect(session.wordsSolved(1, hasPassphrase: false), isTrue);
  });

  for (final replace in [false, true]) {
    test('pending passphrase result is invalid after '
        '${replace ? 'replacement' : 'background'}', () {
      final session = PhysicalBackupSession();
      session.wordsSolved(0, hasPassphrase: true);
      session.beginVerification();
      final epoch = session.passphraseEpoch;
      if (replace) {
        session.replace();
      } else {
        session.setForeground(false);
        session.setForeground(true);
      }
      expect(session.acceptsVerification(epoch), isFalse);
      expect(
        session.phase,
        replace ? PhysicalBackupPhase.words : PhysicalBackupPhase.passphrase,
      );
    });
  }
}
