import 'dart:convert';

import 'package:bb_mobile/core/backup/authenticated_backup_cipher.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/bullnym/domain/bullnym_auth_signer.dart';
import 'package:bb_mobile/features/bullnym/domain/bullnym_backup_actions.dart';
import 'package:bb_mobile/features/bullnym/domain/bullnym_backup_blob.dart';
import 'package:bb_mobile/features/bullnym/domain/bullnym_client_port.dart';
import 'package:bb_mobile/features/bullnym/domain/bullnym_failure.dart';
import 'package:bb_mobile/features/bullnym/domain/bullpay_signing.dart';
import 'package:crypto/crypto.dart';
import 'package:meta/meta.dart';

final class StoreBullnymBackupUsecase {
  final BullnymClientPort _client;
  final int Function() _nowSecs;

  const StoreBullnymBackupUsecase(
    this._client, [
    this._nowSecs = currentBullpayTimestampSecs,
  ]);

  @useResult
  Future<Result<BullnymBackupStoreReceipt, BullnymFailure>> execute({
    required BullnymAuthSigner signer,
    required BullnymBackupStream stream,
    required BullnymBackupHead currentHead,
    required AuthenticatedBackupCiphertext ciphertext,
  }) async {
    final generation = currentHead.generation + 1;
    final ciphertextHash = sha256
        .convert(base64.decode(ciphertext.value))
        .toString();
    final timestamp = _nowSecs();
    final signed = await signWalletBackupAction(
      signer: signer,
      action: walletBackupStoreAction,
      stream: stream,
      generation: generation,
      expectedEtag: currentHead.etag ?? '',
      ciphertextSha256: ciphertextHash,
      ciphertextBytes: ciphertext.byteLength,
      timestampSecs: timestamp,
    );
    final String signature;
    switch (signed) {
      case Err(:final failure):
        return Err(failure);
      case Ok(:final value):
        signature = value;
    }
    final stored = await _client.storeBackup(
      BullnymBackupStoreRequest(
        stream: stream,
        npubHex: signer.npubHex,
        generation: generation,
        expectedEtag: currentHead.etag,
        ciphertext: ciphertext,
        ciphertextSha256: ciphertextHash,
        signatureHex: signature,
        timestamp: timestamp,
      ),
    );
    switch (stored) {
      case Err(:final failure):
        return Err(failure);
      case Ok(value: final receipt):
        final expected = computeWalletBackupEtag(
          stream: stream,
          npubHex: signer.npubHex,
          generation: generation,
          ciphertextSha256: ciphertextHash,
        );
        return switch (expected) {
          Err(:final failure) => Err(failure),
          Ok(value: final expectedEtag) =>
            expectedEtag == receipt.etag && receipt.generation == generation
                ? stored
                : const Err(
                    BullnymFailure.invalidServerResponse(
                      logMessage: 'Backup store receipt is inconsistent',
                    ),
                  ),
        };
    }
  }
}
