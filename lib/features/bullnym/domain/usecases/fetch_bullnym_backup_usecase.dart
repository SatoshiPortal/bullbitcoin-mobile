import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/bullnym/domain/bullnym_auth_signer.dart';
import 'package:bb_mobile/features/bullnym/domain/bullnym_backup_actions.dart';
import 'package:bb_mobile/features/bullnym/domain/bullnym_backup_blob.dart';
import 'package:bb_mobile/features/bullnym/domain/bullnym_client_port.dart';
import 'package:bb_mobile/features/bullnym/domain/bullnym_failure.dart';
import 'package:bb_mobile/features/bullnym/domain/bullpay_signing.dart';
import 'package:meta/meta.dart';

final class FetchBullnymBackupUsecase {
  final BullnymClientPort _client;
  final int Function() _nowSecs;

  const FetchBullnymBackupUsecase(
    this._client, [
    this._nowSecs = currentBullpayTimestampSecs,
  ]);

  @useResult
  Future<Result<BullnymBackupHead, BullnymFailure>> execute({
    required BullnymAuthSigner signer,
    required BullnymBackupStream stream,
  }) async {
    final timestamp = _nowSecs();
    final signed = await signWalletBackupAction(
      signer: signer,
      action: walletBackupFetchAction,
      stream: stream,
      generation: 0,
      expectedEtag: '',
      ciphertextSha256: '',
      ciphertextBytes: 0,
      timestampSecs: timestamp,
    );
    switch (signed) {
      case Err(:final failure):
        return Err(failure);
      case Ok(:final value):
        return _client.fetchBackup(
          BullnymBackupFetchRequest(
            stream: stream,
            npubHex: signer.npubHex,
            signatureHex: value,
            timestamp: timestamp,
          ),
        );
    }
  }
}
