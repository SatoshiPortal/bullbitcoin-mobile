import 'package:bb_mobile/features/bullnym/domain/bullnym_auth_signer.dart';
import 'package:bb_mobile/features/bullnym/domain/bullnym_backup_actions.dart';
import 'package:bb_mobile/features/bullnym/domain/bullnym_backup_blob.dart';
import 'package:bb_mobile/features/bullnym/domain/bullnym_client_port.dart';

final class FetchBullnymBackupUsecase {
  final BullnymClientPort client;
  final int Function() nowSecs;

  const FetchBullnymBackupUsecase(this.client, this.nowSecs);

  Future<BullnymBackupHead> execute({
    required BullnymAuthSigner signer,
    required BullnymBackupStream stream,
  }) async {
    final timestamp = nowSecs();
    return client.fetchBackup(
      BullnymBackupFetchRequest(
        stream: stream,
        npubHex: signer.npubHex,
        timestamp: timestamp,
        signatureHex: await signWalletBackupAction(
          signer: signer,
          action: walletBackupFetchAction,
          stream: stream,
          generation: 0,
          expectedEtag: '',
          ciphertextSha256: '',
          ciphertextBytes: 0,
          timestampSecs: timestamp,
        ),
      ),
    );
  }
}
