import 'package:bb_mobile/features/bullnym/domain/bullnym_auth_signer.dart';
import 'package:bb_mobile/features/bullnym/domain/bullnym_backup_actions.dart';
import 'package:bb_mobile/features/bullnym/domain/bullnym_backup_blob.dart';
import 'package:bb_mobile/features/bullnym/domain/bullnym_client_port.dart';
import 'package:bb_mobile/features/bullnym/domain/bullnym_error.dart';

final class DeleteBullnymBackupUsecase {
  final BullnymClientPort client;
  final int Function() nowSecs;

  const DeleteBullnymBackupUsecase(this.client, this.nowSecs);

  Future<BullnymBackupDeleteReceipt?> execute({
    required BullnymAuthSigner signer,
    required BullnymBackupStream stream,
    required BullnymBackupHead currentHead,
  }) async {
    if (!currentHead.found) return null;
    final timestamp = nowSecs();
    final generation = currentHead.generation + 1;
    final receipt = await client.deleteBackup(
      BullnymBackupDeleteRequest(
        stream: stream,
        npubHex: signer.npubHex,
        generation: generation,
        expectedEtag: currentHead.etag,
        timestamp: timestamp,
        signatureHex: await signWalletBackupAction(
          signer: signer,
          action: walletBackupDeleteAction,
          stream: stream,
          generation: generation,
          expectedEtag: currentHead.etag ?? '',
          ciphertextSha256: '',
          ciphertextBytes: 0,
          timestampSecs: timestamp,
        ),
      ),
    );
    final expectedEtag = computeWalletBackupEtag(
      stream: stream,
      npubHex: signer.npubHex,
      generation: generation,
      ciphertextSha256: '',
    );
    if (receipt.generation != generation || receipt.etag != expectedEtag) {
      throw const BullnymException.invalidServerResponse(
        diagnosticReason: 'Backup delete receipt does not match the request',
      );
    }
    return receipt;
  }
}
