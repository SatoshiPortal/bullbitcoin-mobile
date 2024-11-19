import 'package:bb_mobile/_model/backup.dart';

class BackupState {
  BackupState({this.loading = false, required this.backup});

  final bool loading;
  final Backup backup;
}
