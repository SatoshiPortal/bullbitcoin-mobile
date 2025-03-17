abstract class RecoverBullRepository {
  // Returning BullBackup could be helpful for the frontend that
  String createBackupFile(String backupKey, String plaintext);

  String restoreBackupFile(String backupFile, String backupKey);

  Future<void> storeBackupKey(
    String identifier, // encoded as hex in the file
    String password, // utf8 encoded (argon2 will decode it as utf8)
    String salt, // encoded as hex in the file
    String backupKey,
  );

  Future<String> fetchBackupKey(
    String identifier,
    String password,
    String salt,
  );

  Future<void> trashBackupKey(
    String identifier,
    String password,
    String salt,
  );
}
