import 'package:bb_mobile/features/bullnym/domain/bullnym_auth_signer.dart';
import 'package:bb_mobile/core/backup/authenticated_backup_cipher.dart';
import 'package:bb_mobile/features/bullnym/domain/bullnym_backup_blob.dart';
import 'package:bb_mobile/features/bullnym/domain/bullnym_client_port.dart';
import 'package:bb_mobile/features/bullnym/domain/bullnym_donation_page.dart';
import 'package:bb_mobile/features/bullnym/domain/bullnym_registration.dart';
import 'package:bb_mobile/features/bullnym/domain/bullpay_signing.dart';
import 'package:bb_mobile/features/bullnym/domain/usecases/archive_donation_page_usecase.dart';
import 'package:bb_mobile/features/bullnym/domain/usecases/delete_bullnym_registration_usecase.dart';
import 'package:bb_mobile/features/bullnym/domain/usecases/delete_bullnym_backup_usecase.dart';
import 'package:bb_mobile/features/bullnym/domain/usecases/fetch_bullnym_backup_usecase.dart';
import 'package:bb_mobile/features/bullnym/domain/usecases/get_donation_page_usecase.dart';
import 'package:bb_mobile/features/bullnym/domain/usecases/get_supported_currencies_usecase.dart';
import 'package:bb_mobile/features/bullnym/domain/usecases/lookup_bullnym_registration_usecase.dart';
import 'package:bb_mobile/features/bullnym/domain/usecases/register_bullnym_usecase.dart';
import 'package:bb_mobile/features/bullnym/domain/usecases/save_donation_page_usecase.dart';
import 'package:bb_mobile/features/bullnym/domain/usecases/store_bullnym_backup_usecase.dart';

export 'package:bb_mobile/features/bullnym/domain/bullnym_auth_signer.dart';
export 'package:bb_mobile/core/backup/authenticated_backup_cipher.dart'
    show AuthenticatedBackupCiphertext;
export 'package:bb_mobile/features/bullnym/domain/bullnym_backup_blob.dart';
export 'package:bb_mobile/features/bullnym/domain/bullnym_donation_page.dart';
export 'package:bb_mobile/features/bullnym/domain/bullnym_error.dart';
export 'package:bb_mobile/features/bullnym/domain/bullnym_registration.dart';

class BullnymFacade {
  final RegisterBullnymUsecase _register;
  final DeleteBullnymRegistrationUsecase _deleteRegistration;
  final LookupBullnymRegistrationUsecase _lookupRegistration;
  final FetchBullnymBackupUsecase _fetchBackup;
  final StoreBullnymBackupUsecase _storeBackup;
  final DeleteBullnymBackupUsecase _deleteBackup;
  final GetDonationPageUsecase _getDonationPage;
  final SaveDonationPageUsecase _saveDonationPage;
  final ArchiveDonationPageUsecase _archiveDonationPage;
  final GetSupportedCurrenciesUsecase _getSupportedCurrencies;

  BullnymFacade({
    required BullnymClientPort client,
    int Function() nowSecs = currentBullpayTimestampSecs,
  }) : _register = RegisterBullnymUsecase(client, nowSecs),
       _deleteRegistration = DeleteBullnymRegistrationUsecase(client, nowSecs),
       _lookupRegistration = LookupBullnymRegistrationUsecase(client),
       _fetchBackup = FetchBullnymBackupUsecase(client, nowSecs),
       _storeBackup = StoreBullnymBackupUsecase(client, nowSecs),
       _deleteBackup = DeleteBullnymBackupUsecase(client, nowSecs),
       _getDonationPage = GetDonationPageUsecase(client),
       _saveDonationPage = SaveDonationPageUsecase(client, nowSecs),
       _archiveDonationPage = ArchiveDonationPageUsecase(client, nowSecs),
       _getSupportedCurrencies = GetSupportedCurrenciesUsecase(client);

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

  Future<BullnymDonationPage> getDonationPage({
    required String nym,
    required String kind,
  }) {
    return _getDonationPage.execute(nym: nym, kind: kind);
  }

  // `kind` is surfaced (not pinned) so the future POS surface reuses this
  // client; the payment_page feature pins `kind = payment_page`.
  Future<BullnymDonationPage> saveDonationPage({
    required BullnymAuthSigner signer,
    required String nym,
    required String ctDescriptor,
    required String header,
    required String description,
    required String displayCurrency,
    required String website,
    required String twitter,
    required String instagram,
    required bool enabled,
    required String kind,
  }) {
    return _saveDonationPage.execute(
      signer: signer,
      nym: nym,
      ctDescriptor: ctDescriptor,
      header: header,
      description: description,
      displayCurrency: displayCurrency,
      website: website,
      twitter: twitter,
      instagram: instagram,
      enabled: enabled,
      kind: kind,
    );
  }

  Future<BullnymDonationPage> archiveDonationPage({
    required BullnymAuthSigner signer,
    required String nym,
    required String kind,
  }) {
    return _archiveDonationPage.execute(signer: signer, nym: nym, kind: kind);
  }

  Future<BullnymSupportedCurrencies> getSupportedCurrencies() {
    return _getSupportedCurrencies.execute();
  }

  @override
  String toString() => 'BullnymFacade';
}
