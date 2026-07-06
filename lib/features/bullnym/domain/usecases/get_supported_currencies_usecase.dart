import 'package:bb_mobile/features/bullnym/domain/bullnym_client_port.dart';
import 'package:bb_mobile/features/bullnym/domain/bullnym_donation_page.dart';

/// Unsigned public GET of the server's live supported-currencies list.
class GetSupportedCurrenciesUsecase {
  final BullnymClientPort _client;

  const GetSupportedCurrenciesUsecase(this._client);

  Future<BullnymSupportedCurrencies> execute() {
    return _client.getSupportedCurrencies();
  }
}
