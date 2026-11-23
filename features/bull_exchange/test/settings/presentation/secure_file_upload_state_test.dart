import 'package:bull_exchange/src/settings/presentation/secure_file_upload_state.dart';
import 'package:exchange/exchange.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final table = {
    KycDocumentStatus.notUploaded: (SecureUploadStatus.upload, true),
    KycDocumentStatus.underReview: (SecureUploadStatus.inReview, false),
    KycDocumentStatus.accepted: (SecureUploadStatus.accepted, false),
    KycDocumentStatus.rejected: (SecureUploadStatus.rejected, true),
    KycDocumentStatus.unknown: (SecureUploadStatus.unknown, false),
  };

  test('the table names every KYC document status', () {
    expect(table.keys, containsAll(KycDocumentStatus.values));
  });

  for (final MapEntry(key: status, value: (ui, canUpload)) in table.entries) {
    test('$status shows $ui and ${canUpload ? 'offers' : 'does not offer'} '
        'an upload', () {
      final state = SecureFileUploadState(
        isUserDataLoaded: true,
        secureFileUploadStatus: status,
      );
      expect(state.secureUploadStatus, ui);
      expect(state.canAddMoreFiles, canUpload);
    });
  }
}
