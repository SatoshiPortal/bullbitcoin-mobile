import 'dart:io';

class FetchBackupFromFileSystemUsecase {
  FetchBackupFromFileSystemUsecase();

  Future<String> execute(String filePath) async {
    try {
      final backupFile = File(filePath);
      if (!await backupFile.exists()) {
        throw 'Backup file does not exist';
      }
      return await backupFile.readAsString();
    } catch (e) {
      throw Exception(e.toString());
    }
  }
}
