import 'dart:convert';

import 'package:bb_mobile/core/backup/authenticated_backup_cipher.dart';
import 'package:bb_mobile/features/bullnym/domain/bullnym_auth_signer.dart';
import 'package:bb_mobile/features/bullnym/domain/bullnym_backup_actions.dart';
import 'package:bb_mobile/features/bullnym/domain/bullnym_backup_blob.dart';
import 'package:bb_mobile/features/bullnym/domain/bullnym_client_port.dart';
import 'package:bb_mobile/features/bullnym/domain/bullnym_error.dart';
import 'package:crypto/crypto.dart';

final class StoreBullnymBackupUsecase {
  final BullnymClientPort client;
  final int Function() nowSecs;

  const StoreBullnymBackupUsecase(this.client, this.nowSecs);

  Future<BullnymBackupStoreReceipt> execute({
    required BullnymAuthSigner signer,
    required BullnymBackupStream stream,
    required BullnymBackupHead currentHead,
    required AuthenticatedBackupCiphertext ciphertext,
  }) async {
    final timestamp = nowSecs();
    final generation = currentHead.generation + 1;
    final ciphertextHash = sha256
        .convert(base64.decode(ciphertext.value))
        .toString();
    final receipt = await client.storeBackup(
      BullnymBackupStoreRequest(
        stream: stream,
        npubHex: signer.npubHex,
        generation: generation,
        expectedEtag: currentHead.etag,
        ciphertext: ciphertext,
        ciphertextSha256: ciphertextHash,
        timestamp: timestamp,
        signatureHex: await signWalletBackupAction(
          signer: signer,
          action: walletBackupStoreAction,
          stream: stream,
          generation: generation,
          expectedEtag: currentHead.etag ?? '',
          ciphertextSha256: ciphertextHash,
          ciphertextBytes: ciphertext.byteLength,
          timestampSecs: timestamp,
        ),
      ),
    );
    final expectedEtag = computeWalletBackupEtag(
      stream: stream,
      npubHex: signer.npubHex,
      generation: generation,
      ciphertextSha256: ciphertextHash,
    );
    if (receipt.generation != generation || receipt.etag != expectedEtag) {
      throw const BullnymException.invalidServerResponse(
        diagnosticReason: 'Backup store receipt does not match the request',
      );
    }
    return receipt;
  }
}
