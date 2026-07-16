import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/bullnym/domain/bullnym_auth_signer.dart';
import 'package:bb_mobile/features/bullnym/domain/bullnym_backup_actions.dart';
import 'package:bb_mobile/features/bullnym/domain/bullnym_backup_blob.dart';
import 'package:bb_mobile/features/bullnym/domain/bullnym_client_port.dart';
import 'package:bb_mobile/features/bullnym/domain/bullnym_failure.dart';
import 'package:bb_mobile/features/bullnym/domain/bullpay_signing.dart';
import 'package:meta/meta.dart';

final class DeleteBullnymBackupUsecase {
  final BullnymClientPort _client;
  final int Function() _nowSecs;

  const DeleteBullnymBackupUsecase(
    this._client, [
    this._nowSecs = currentBullpayTimestampSecs,
  ]);

  @useResult
  Future<Result<BullnymBackupDeleteReceipt?, BullnymFailure>> execute({
    required BullnymAuthSigner signer,
    required BullnymBackupStream stream,
    required BullnymBackupHead currentHead,
  }) async {
    if (!currentHead.found) return const Ok(null);
    final etag = currentHead.etag;
    if (etag == null) {
      return const Err(
        BullnymFailure.invalidInput('Backup delete head is incomplete'),
      );
    }
    final generation = currentHead.generation + 1;
    final timestamp = _nowSecs();
    final signed = await signWalletBackupAction(
      signer: signer,
      action: walletBackupDeleteAction,
      stream: stream,
      generation: generation,
      expectedEtag: etag,
      ciphertextSha256: '',
      ciphertextBytes: 0,
      timestampSecs: timestamp,
    );
    final String signature;
    switch (signed) {
      case Err(:final failure):
        return Err(failure);
      case Ok(:final value):
        signature = value;
    }
    final deleted = await _client.deleteBackup(
      BullnymBackupDeleteRequest(
        stream: stream,
        npubHex: signer.npubHex,
        generation: generation,
        expectedEtag: etag,
        signatureHex: signature,
        timestamp: timestamp,
      ),
    );
    switch (deleted) {
      case Err(:final failure):
        return Err(failure);
      case Ok(value: final receipt):
        final expected = computeWalletBackupEtag(
          stream: stream,
          npubHex: signer.npubHex,
          generation: generation,
          ciphertextSha256: '',
        );
        return switch (expected) {
          Err(:final failure) => Err(failure),
          Ok(value: final expectedEtag) =>
            expectedEtag == receipt.etag && receipt.generation == generation
                ? Ok(receipt)
                : const Err(
                    BullnymFailure.invalidServerResponse(
                      logMessage: 'Backup delete receipt is inconsistent',
                    ),
                  ),
        };
    }
  }
}
