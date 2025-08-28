class RecoverBullSelectVaultError implements Exception {
  final String message;
  RecoverBullSelectVaultError(this.message);

  @override
  String toString() => message;
}

class FetchAllDriveBackupsError extends RecoverBullSelectVaultError {
  FetchAllDriveBackupsError() : super('Failed to fetch all drive backups');
}
