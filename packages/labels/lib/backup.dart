/// Wallet-scoped capture and additive restoration of labels and freezes.
library;

export 'src/domain/label_backup_scope.dart' show LabelBackupScope;
export 'src/domain/label_failure.dart' show LabelBackupStalePlanFailure;
export 'src/domain/labels_merge.dart';
export 'src/domain/labels_snapshot.dart';
export 'src/public/labels.dart' show LabelBackups;
