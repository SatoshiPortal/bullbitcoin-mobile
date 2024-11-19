import 'package:bb_mobile/_model/backup.dart';

class BackupState {
  BackupState({this.loading = false, required this.backups});

  final bool loading;
  final List<Backup> backups;
}
