import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/bullnym/domain/bullnym_client_port.dart';
import 'package:bb_mobile/features/bullnym/domain/bullnym_donation_page.dart';
import 'package:bb_mobile/features/bullnym/domain/bullnym_failure.dart';
import 'package:meta/meta.dart';

/// Unsigned public GET of the donation-page row (kind-scoped).
class GetDonationPageUsecase {
  final BullnymClientPort _client;

  const GetDonationPageUsecase(this._client);

  @useResult
  Future<Result<BullnymDonationPage, BullnymFailure>> execute({
    required String nym,
    required String kind,
  }) {
    return _client.getDonationPage(nym: nym, kind: kind);
  }
}
