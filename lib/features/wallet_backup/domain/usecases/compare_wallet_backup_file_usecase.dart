import 'dart:convert';
import 'dart:typed_data';

import 'package:bb_mobile/features/wallet_backup/domain/entities/wallet_backup_file_comparison.dart';
import 'package:bb_mobile/features/wallet_backup/domain/entities/wallet_backup_remote.dart';
import 'package:bb_mobile/features/wallet_backup/domain/entities/wallet_backup_snapshot.dart';
import 'package:bb_mobile/features/wallet_backup/domain/entities/wallet_backup_state.dart';
import 'package:bb_mobile/features/wallet_backup/domain/wallet_backup_failure.dart';
import 'package:primitives/primitives.dart';

typedef CompareWalletBackupSnapshots =
    Set<WalletBackupDifference> Function(
      WalletBackupSnapshot left,
      WalletBackupSnapshot right,
    );
typedef DecodeWalletBackupFile =
    Future<Result<WalletBackupSnapshot, WalletBackupFailure>> Function(
      Uint8List bytes,
    );

final class CompareWalletBackupFileUsecase {
  final DecodeWalletBackupFile _decodeFile;
  final Future<Result<WalletBackupState, WalletBackupFailure>> Function()
  _getState;
  final Future<Result<WalletBackupRemoteHead, WalletBackupFailure>> Function()
  _fetchRemote;
  final Future<Result<WalletBackupSnapshot?, WalletBackupFailure>> Function(
    WalletBackupRemoteHead,
  )
  _fetchImport;
  final CompareWalletBackupSnapshots _differences;

  const CompareWalletBackupFileUsecase(
    this._decodeFile,
    this._getState,
    this._fetchRemote,
    this._fetchImport,
    this._differences,
  );

  Future<Result<WalletBackupImportComparison, WalletBackupFailure>> execute(
    Uint8List bytes,
  ) async {
    final WalletBackupSnapshot file;
    switch (await _decodeFile(bytes)) {
      case Err(:final failure):
        return Err(failure);
      case Ok(:final value):
        file = value;
    }

    final WalletBackupState state;
    switch (await _getState()) {
      case Err(:final failure):
        return Err(failure);
      case Ok(:final value):
        state = value;
    }
    final noServerSituation = state.enabled
        ? WalletBackupImportSituation.noServerBackup
        : WalletBackupImportSituation.automaticBackupDisabled;
    final WalletBackupRemoteHead head;
    switch (await _fetchRemote()) {
      case Err(failure: WalletBackupRemoteUnavailableFailure()):
        return Ok(
          _withoutServer(file, WalletBackupImportSituation.serverUnavailable),
        );
      case Err(:final failure):
        return Err(failure);
      case Ok(value: final value) when !value.found:
        return Ok(_withoutServer(file, noServerSituation, head: value));
      case Ok(:final value):
        head = value;
    }
    final WalletBackupSnapshot server;
    switch (await _fetchImport(head)) {
      case Err(failure: WalletBackupRemoteUnavailableFailure()):
        return Ok(
          _withoutServer(file, WalletBackupImportSituation.serverUnavailable),
        );
      case Err(:final failure):
        return Err(failure);
      case Ok(value: null):
        return Ok(_withoutServer(file, noServerSituation, head: head));
      case Ok(value: final value?):
        server = value;
    }
    final differences = _differences(file, server);
    return Ok(
      WalletBackupImportComparison(
        situation: differences.isEmpty
            ? WalletBackupImportSituation.same
            : WalletBackupImportSituation.different,
        file: _summary(file),
        server: _summary(server),
        comparedServerGeneration: head.generation,
        comparedServerEtag: head.etag,
        serverCiphertextBytes: Uint8List.fromList(
          utf8.encode(head.ciphertext!.value),
        ),
        differences: differences,
      ),
    );
  }

  WalletBackupImportComparison _withoutServer(
    WalletBackupSnapshot file,
    WalletBackupImportSituation situation, {
    WalletBackupRemoteHead? head,
  }) => WalletBackupImportComparison(
    situation: situation,
    file: _summary(file),
    server: null,
    comparedServerGeneration: head?.generation,
    comparedServerEtag: head?.etag,
    differences: const {},
  );
}

WalletBackupSnapshotSummary _summary(WalletBackupSnapshot snapshot) {
  final metadata = snapshot.metadata;
  return WalletBackupSnapshotSummary(
    createdAt: snapshot.createdAt,
    walletCount: snapshot.recoveryManifest.wallets.length,
    nostrIdentityCount: snapshot.recoveryManifest.nostrKeys.length,
    externalWalletCount: snapshot.externalWalletDefinitions.length,
    labelCount: metadata?.labels.length ?? 0,
    frozenOutpointCount: metadata?.frozenOutpoints.length ?? 0,
    walletPreferenceCount: metadata?.walletPreferences.length ?? 0,
  );
}
