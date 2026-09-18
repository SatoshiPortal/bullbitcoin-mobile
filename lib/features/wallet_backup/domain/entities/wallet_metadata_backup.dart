import 'package:bb_mobile/features/labels/labels_facade.dart';
import 'package:bb_mobile/features/wallet_backup/domain/entities/wallet_portable_settings_backup.dart';

final class WalletMetadataBackup {
  final List<LabelEntity> labels;
  final List<BackupFrozenOutput> frozenOutputs;
  final WalletPortableSettingsBackup settings;

  WalletMetadataBackup({
    required List<LabelEntity> labels,
    required List<BackupFrozenOutput> frozenOutputs,
    required this.settings,
  }) : labels = List.unmodifiable(labels),
       frozenOutputs = List.unmodifiable(frozenOutputs) {
    if (frozenOutputs.map((o) => (o.txId, o.vout)).toSet().length !=
        frozenOutputs.length) {
      throw const FormatException('Duplicate frozen output');
    }
  }
}

final class BackupFrozenOutput {
  final String? walletReference;
  final String txId;
  final int vout;

  BackupFrozenOutput({
    required this.walletReference,
    required this.txId,
    required this.vout,
  }) {
    final hex = RegExp(r'^[0-9a-f]{64}$');
    if (!hex.hasMatch(txId) ||
        vout < 0 ||
        vout > 0xffffffff ||
        (walletReference != null && !hex.hasMatch(walletReference!))) {
      throw const FormatException('Invalid frozen output');
    }
  }
}
