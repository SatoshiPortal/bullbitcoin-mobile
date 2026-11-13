/// A missing or historic record is unknown until a real test succeeds.
final class BackupStatus {
  final DateTime? storedAt;
  final DateTime? verifiedAt;

  const BackupStatus({this.storedAt, this.verifiedAt});

  bool get isVerified => verifiedAt != null;
}
