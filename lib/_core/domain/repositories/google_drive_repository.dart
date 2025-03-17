import 'package:bb_mobile/_core/domain/entities/drive_file.dart';

abstract class GoogleDriveRepository {
  Future<void> connect();
  Future<void> disconnect();
  Future<List<DriveFile>> fetchBackupFiles();
  Future<String> fetchBackupContent(String fileId);
  Future<void> storeBackup(String content);
  Future<void> trashBackup(String path);
}
