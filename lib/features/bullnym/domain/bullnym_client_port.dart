import 'package:bb_mobile/core/backup/authenticated_backup_cipher.dart';
import 'package:bb_mobile/features/bullnym/domain/bullnym_backup_blob.dart';
import 'package:bb_mobile/features/bullnym/domain/bullnym_donation_page.dart';
import 'package:bb_mobile/features/bullnym/domain/bullnym_registration.dart';

abstract interface class BullnymClientPort {
  Future<BullnymRegisterResult> register(BullnymRegisterRequest request);

  Future<void> deleteRegistration(BullnymDeleteRegistrationRequest request);

  Future<BullnymLookupResult> lookupRegistration({required String npubHex});

  Future<BullnymBackupHead> fetchBackup(BullnymBackupFetchRequest request);

  Future<BullnymBackupStoreReceipt> storeBackup(
    BullnymBackupStoreRequest request,
  );

  Future<BullnymBackupDeleteReceipt> deleteBackup(
    BullnymBackupDeleteRequest request,
  );

  /// Public read of the current donation-page row for `nym`/`kind`. Throws a
  /// `serverRejectedRequest` with code `DonationPageNotFound` when absent.
  Future<BullnymDonationPage> getDonationPage({
    required String nym,
    required String kind,
  });

  Future<BullnymDonationPage> saveDonationPage(
    BullnymSaveDonationPageRequest request,
  );

  Future<BullnymDonationPage> archiveDonationPage(
    BullnymArchiveDonationPageRequest request,
  );

  Future<BullnymSupportedCurrencies> getSupportedCurrencies();
}

class BullnymBackupFetchRequest {
  final BullnymBackupStream stream;
  final String npubHex;
  final String signatureHex;
  final int timestamp;

  const BullnymBackupFetchRequest({
    required this.stream,
    required this.npubHex,
    required this.signatureHex,
    required this.timestamp,
  });
}

class BullnymBackupStoreRequest {
  final BullnymBackupStream stream;
  final String npubHex;
  final int generation;
  final String? expectedEtag;
  final AuthenticatedBackupCiphertext ciphertext;
  final String ciphertextSha256;
  final String signatureHex;
  final int timestamp;

  const BullnymBackupStoreRequest({
    required this.stream,
    required this.npubHex,
    required this.generation,
    required this.expectedEtag,
    required this.ciphertext,
    required this.ciphertextSha256,
    required this.signatureHex,
    required this.timestamp,
  });
}

class BullnymBackupDeleteRequest {
  final BullnymBackupStream stream;
  final String npubHex;
  final int generation;
  final String? expectedEtag;
  final String signatureHex;
  final int timestamp;

  const BullnymBackupDeleteRequest({
    required this.stream,
    required this.npubHex,
    required this.generation,
    required this.expectedEtag,
    required this.signatureHex,
    required this.timestamp,
  });
}

class BullnymRegisterRequest {
  final String nym;
  final String ctDescriptor;
  final String npubHex;
  final String signatureHex;
  final int timestamp;

  const BullnymRegisterRequest({
    required this.nym,
    required this.ctDescriptor,
    required this.npubHex,
    required this.signatureHex,
    required this.timestamp,
  });
}

class BullnymDeleteRegistrationRequest {
  final String nym;
  final String npubHex;
  final String signatureHex;
  final int timestamp;

  const BullnymDeleteRegistrationRequest({
    required this.nym,
    required this.npubHex,
    required this.signatureHex,
    required this.timestamp,
  });
}
