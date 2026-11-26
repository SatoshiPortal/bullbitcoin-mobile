import 'package:exchange/exchange.dart';
import 'package:exchange/src/data/bbx_api_user_summary_mapper.dart';
import 'package:exchange/src/data/unknown_server_value.dart';
import 'package:test/test.dart';

void main() {
  test('every API-Users KycStatusEndUser value maps, in any case', () {
    expect(
      kycDocumentStatusFromWire('NOT_UPLOADED'),
      KycDocumentStatus.notUploaded,
    );
    expect(
      kycDocumentStatusFromWire('UNDER_REVIEW'),
      KycDocumentStatus.underReview,
    );
    expect(kycDocumentStatusFromWire('accepted'), KycDocumentStatus.accepted);
    expect(kycDocumentStatusFromWire('Rejected'), KycDocumentStatus.rejected);
  });

  test(
    'an unknown value is unknown, not "not uploaded", and is logged once',
    () {
      expect(kycDocumentStatusFromWire('EXPIRED'), KycDocumentStatus.unknown);
      expect(
        UnknownServerValues.report('KYC document status', 'EXPIRED'),
        isFalse,
      );
    },
  );

  test('predicates', () {
    for (final status in KycDocumentStatus.values) {
      expect(
        status.isTerminal,
        status == KycDocumentStatus.accepted ||
            status == KycDocumentStatus.rejected,
        reason: '$status',
      );
      expect(status.isFailed, isFalse, reason: '$status');
    }
  });
}
