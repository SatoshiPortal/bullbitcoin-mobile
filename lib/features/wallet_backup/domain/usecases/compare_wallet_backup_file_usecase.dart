import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/keychain_manifest/public/keychain_manifest_facade.dart';
import 'package:bb_mobile/features/wallet_backup/domain/entities/wallet_backup_file.dart';
import 'package:bb_mobile/features/wallet_backup/domain/entities/wallet_backup_file_comparison.dart';
import 'package:bb_mobile/features/wallet_backup/domain/repositories/wallet_backup_codec_repository.dart';
import 'package:bb_mobile/features/wallet_backup/domain/repositories/wallet_backup_state_repository.dart';
import 'package:bb_mobile/features/wallet_backup/domain/usecases/inspect_wallet_backup_usecase.dart';
import 'package:bb_mobile/features/wallet_backup/domain/usecases/manage_wallet_backup_files_usecase.dart';
import 'package:bb_mobile/features/wallet_backup/domain/wallet_backup_failure.dart';
import 'package:meta/meta.dart';

final class CompareWalletBackupFileUsecase {
  final DecodeWalletBackupFileUsecase _decode;
  final InspectWalletBackupUsecase _inspect;
  final WalletBackupStateRepository _state;
  final WalletBackupCodecRepository _codec;
  const CompareWalletBackupFileUsecase({
    required this._decode,
    required this._inspect,
    required this._state,
    required this._codec,
  });

  @useResult
  Future<Result<WalletBackupFileComparison, WalletBackupFailure>> execute(
    String source, {
    String? words,
  }) async {
    final decoded = await _decode.execute(source, words: words);
    if (decoded case Err(:final failure)) return Err(failure);
    final file = (decoded as Ok<WalletBackupFile, WalletBackupFailure>).value;
    final control = await _state.getControl();
    if (control case Err(:final failure)) return Err(failure);
    final enabled = control.fold(
      (value) => value.enabled == true,
      (_) => false,
    );
    switch (await _inspect.execute(words: words)) {
      case Err(:final failure):
        return Ok(
          WalletBackupFileComparison(
            file: file,
            server: null,
            automaticBackupEnabled: enabled,
            serverFailure: failure,
          ),
        );
      case Ok(:final value):
        if (value.identity !=
            file.snapshot.manifest.backupIdentities
                .singleWhere((key) => key.kind == BackupIdentityKind.server)
                .publicKey) {
          return const Err(WalletBackupCredentialFailure());
        }
        final differences = value.snapshot == null
            ? const Ok<Set<WalletBackupDifference>, WalletBackupFailure>({})
            : _codec.differences(file.snapshot, value.snapshot!);
        return differences.map(
          (changes) => WalletBackupFileComparison(
            file: file,
            server: value,
            automaticBackupEnabled: enabled,
            differences: changes,
          ),
        );
    }
  }
}
