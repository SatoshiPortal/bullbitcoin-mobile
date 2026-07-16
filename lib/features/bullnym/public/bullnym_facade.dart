import 'package:bb_mobile/features/bullnym/domain/bullnym_auth_signer.dart';
import 'package:bb_mobile/core/backup/authenticated_backup_cipher.dart';
import 'package:bb_mobile/features/bullnym/domain/bullnym_backup_blob.dart';
import 'package:bb_mobile/features/bullnym/domain/bullnym_client_port.dart';
import 'package:bb_mobile/features/bullnym/domain/bullnym_registration.dart';
import 'package:bb_mobile/features/bullnym/domain/bullpay_signing.dart';
import 'package:bb_mobile/features/bullnym/domain/usecases/delete_bullnym_registration_usecase.dart';
import 'package:bb_mobile/features/bullnym/domain/usecases/delete_bullnym_backup_usecase.dart';
import 'package:bb_mobile/features/bullnym/domain/usecases/fetch_bullnym_backup_usecase.dart';
import 'package:bb_mobile/features/bullnym/domain/usecases/lookup_bullnym_registration_usecase.dart';
import 'package:bb_mobile/features/bullnym/domain/usecases/register_bullnym_usecase.dart';
import 'package:bb_mobile/features/bullnym/domain/usecases/store_bullnym_backup_usecase.dart';

export 'package:bb_mobile/features/bullnym/domain/bullnym_auth_signer.dart';
export 'package:bb_mobile/core/backup/authenticated_backup_cipher.dart'
    show AuthenticatedBackupCiphertext;
export 'package:bb_mobile/features/bullnym/domain/bullnym_backup_blob.dart';
export 'package:bb_mobile/features/bullnym/domain/bullnym_error.dart';
export 'package:bb_mobile/features/bullnym/domain/bullnym_registration.dart';

class BullnymFacade {
  final RegisterBullnymUsecase _register;
  final DeleteBullnymRegistrationUsecase _deleteRegistration;
  final LookupBullnymRegistrationUsecase _lookupRegistration;
  final FetchBullnymBackupUsecase _fetchBackup;
  final StoreBullnymBackupUsecase _storeBackup;
  final DeleteBullnymBackupUsecase _deleteBackup;

  BullnymFacade({
    required BullnymClientPort client,
    int Function() nowSecs = currentBullpayTimestampSecs,
  }) : _register = RegisterBullnymUsecase(client, nowSecs),
       _deleteRegistration = DeleteBullnymRegistrationUsecase(client, nowSecs),
       _lookupRegistration = LookupBullnymRegistrationUsecase(client),
       _fetchBackup = FetchBullnymBackupUsecase(client, nowSecs),
       _storeBackup = StoreBullnymBackupUsecase(client, nowSecs),
       _deleteBackup = DeleteBullnymBackupUsecase(client, nowSecs);

  Future<BullnymRegisterResult> register({
    required BullnymAuthSigner signer,
    required String nym,
    required String ctDescriptor,
  }) {
    return _register.execute(
      signer: signer,
      nym: nym,
      ctDescriptor: ctDescriptor,
    );
  }

  Future<void> deleteRegistration({
    required BullnymAuthSigner signer,
    required String nym,
  }) {
    return _deleteRegistration.execute(signer: signer, nym: nym);
  }

  Future<BullnymLookupResult> lookupRegistration({required String npubHex}) {
    return _lookupRegistration.execute(npubHex: npubHex);
  }

  Future<BullnymBackupHead> fetchBackup({
    required BullnymAuthSigner signer,
    required BullnymBackupStream stream,
  }) => _fetchBackup.execute(signer: signer, stream: stream);

  Future<BullnymBackupStoreReceipt> storeBackup({
    required BullnymAuthSigner signer,
    required BullnymBackupStream stream,
    required BullnymBackupHead currentHead,
    required AuthenticatedBackupCiphertext ciphertext,
  }) => _storeBackup.execute(
    signer: signer,
    stream: stream,
    currentHead: currentHead,
    ciphertext: ciphertext,
  );

  Future<BullnymBackupDeleteReceipt?> deleteBackup({
    required BullnymAuthSigner signer,
    required BullnymBackupStream stream,
    required BullnymBackupHead currentHead,
  }) => _deleteBackup.execute(
    signer: signer,
    stream: stream,
    currentHead: currentHead,
  );

  @override
  String toString() => 'BullnymFacade';
}
