enum PhysicalBackupPhase { words, passphrase, verifying, reported }

/// Coordinates a challenge without holding recovery material or a secret handle.
final class PhysicalBackupSession {
  PhysicalBackupPhase phase = PhysicalBackupPhase.words;
  int placed = 0;
  int total = 0;
  int challengeEpoch = 0;
  int passphraseEpoch = 0;
  bool foreground = true;
  bool _passphraseMode = false;

  bool get needsPassphrase => _passphraseMode;
  bool get canVerify => foreground && phase == PhysicalBackupPhase.passphrase;

  void replace() {
    challengeEpoch++;
    placed = 0;
    total = 0;
    phase = PhysicalBackupPhase.words;
    _passphraseMode = false;
    clearInput();
  }

  void clearInput() {
    passphraseEpoch++;
    if (phase == PhysicalBackupPhase.verifying) {
      phase = PhysicalBackupPhase.passphrase;
    }
  }

  void setForeground(bool value) {
    foreground = value;
    if (value) return;
    clearInput();
    if (!_passphraseMode) {
      challengeEpoch++;
      placed = 0;
      total = 0;
    }
  }

  bool acceptsWords(int epoch) => foreground && epoch == challengeEpoch;

  bool wordsSolved(int epoch, {required bool hasPassphrase}) {
    if (!acceptsWords(epoch) || phase == PhysicalBackupPhase.reported) {
      return false;
    }
    if (hasPassphrase) {
      _passphraseMode = true;
      if (phase == PhysicalBackupPhase.words) {
        phase = PhysicalBackupPhase.passphrase;
      }
      return false;
    }
    phase = PhysicalBackupPhase.reported;
    return true;
  }

  bool beginVerification() {
    if (!canVerify) return false;
    phase = PhysicalBackupPhase.verifying;
    return true;
  }

  bool acceptsVerification(int epoch) =>
      foreground &&
      phase == PhysicalBackupPhase.verifying &&
      epoch == passphraseEpoch;

  void finishVerification({required bool verified}) {
    phase = verified
        ? PhysicalBackupPhase.reported
        : PhysicalBackupPhase.passphrase;
  }
}
