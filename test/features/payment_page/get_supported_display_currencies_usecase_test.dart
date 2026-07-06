import 'package:bb_mobile/features/bullnym/public/bullnym_facade.dart';
import 'package:bb_mobile/features/payment_page/domain/payment_page_error.dart';
import 'package:bb_mobile/features/payment_page/domain/usecases/get_supported_display_currencies_usecase.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/recording_bullnym_client.dart';

void main() {
  late RecordingBullnymClient client;
  late BullnymFacade bullnym;
  late GetSupportedDisplayCurrenciesUsecase usecase;

  setUp(() {
    client = RecordingBullnymClient();
    bullnym = BullnymFacade(client: client);
    usecase = GetSupportedDisplayCurrenciesUsecase(bullnym);
  });

  test('maps the server currencies to display currencies', () async {
    client.currencies = const [
      BullnymSupportedCurrency(code: 'CAD', precision: 2),
      BullnymSupportedCurrency(code: 'COP', precision: 0),
    ];

    final result = await usecase.execute();

    expect(result.map((c) => c.code), ['CAD', 'COP']);
    expect(result.last.precision, 0);
  });

  test('propagates a typed failure', () async {
    client.currenciesError = const BullnymException.network(
      diagnosticReason: 'offline',
    );

    await expectLater(
      usecase.execute(),
      throwsA(
        isA<PaymentPageException>().having(
          (e) => e.kind,
          'kind',
          PaymentPageErrorKind.network,
        ),
      ),
    );
  });
}
