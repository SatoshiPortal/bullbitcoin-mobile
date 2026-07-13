import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/bullnym/domain/bullnym_client_port.dart';
import 'package:bb_mobile/features/bullnym/domain/bullnym_donation_page.dart';
import 'package:bb_mobile/features/bullnym/domain/bullnym_failure.dart';
import 'package:meta/meta.dart';

/// Unsigned public GET of the server's live supported-currencies list.
class GetSupportedCurrenciesUsecase {
  final BullnymClientPort _client;

  const GetSupportedCurrenciesUsecase(this._client);

  @useResult
  Future<Result<BullnymSupportedCurrencies, BullnymFailure>> execute() {
    return _client.getSupportedCurrencies();
  }
}
