enum CurrentKeyServerFlow {
  enter,
  confirm,
  recovery,
  recoveryWithBackupKey,
  delete;

  static CurrentKeyServerFlow fromString(String value) {
    return CurrentKeyServerFlow.values.firstWhere(
      (element) => element.name.toLowerCase() == value.toLowerCase(),
      orElse: () => CurrentKeyServerFlow.enter,
    );
  }
}

enum AuthInputType { pin, password, encryptionKey }

enum SecretStatus { initial, stored, recovered, deleted }

enum TorStatus { online, offline, connecting, disconnecting }
