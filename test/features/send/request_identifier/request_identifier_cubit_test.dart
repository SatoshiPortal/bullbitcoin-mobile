import 'package:primitives/primitives.dart' show BitcoinUnit;
import 'dart:typed_data';

import 'package:bb_mobile/core/settings/domain/get_settings_usecase.dart';
import 'package:bb_mobile/features/settings/domain/settings_entity.dart';
import 'package:bb_mobile/features/send/domain/usecases/detect_bitcoin_string_usecase.dart';
import 'package:bb_mobile/features/send/domain/send_failure.dart';
import 'package:bb_mobile/features/send/request_identifier/request_identifier_cubit.dart';
import 'package:bb_mobile/features/send/request_identifier/request_identifier_state.dart';
import 'package:bull_sdk/bdk.dart' as bdk;
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockGetSettingsUsecase extends Mock implements GetSettingsUsecase {}

void main() {
  const bitcoinAddress = 'bc1qar0srrr7xfkvy5l643lydnw9re59gtzzwf5mdq';

  test('redirects only after the scanned request has parsed', () async {
    final cubit = RequestIdentifierCubit();
    addTearDown(cubit.close);

    await cubit.onScanned(bitcoinAddress);

    expect(cubit.state.redirect, RequestIdentifierRedirect.toSend);
    expect(cubit.state.failure, isNull);
  });

  test('models an invalid request as a Send failure', () async {
    final cubit = RequestIdentifierCubit();
    addTearDown(cubit.close);
    cubit.updateRawRequest('not-a-payment-request');

    await cubit.validatePaymentRequest();

    expect(cubit.state.redirect, isNull);
    expect(cubit.state.failure, isA<SendInvalidPaymentRequestFailure>());
  });

  for (final environment in Environment.values) {
    for (final useBip21 in [false, true]) {
      test(
        '${environment.name} ${useBip21 ? 'BIP21' : 'raw'} regtest routing',
        () async {
          final settings = _MockGetSettingsUsecase();
          when(() => settings.execute()).thenAnswer(
            (_) async => SettingsEntity(
              environment: environment,
              bitcoinUnit: BitcoinUnit.btc,
              currencyCode: 'USD',
              isSuperuser: true,
              isDevModeEnabled: true,
            ),
          );
          final script = bdk.Script(
            rawOutputScript: Uint8List.fromList([0, 20, ...List.filled(20, 1)]),
          );
          addTearDown(script.dispose);
          final address = bdk.Address.fromScript(
            script: script,
            network: bdk.Network.regtest,
          );
          addTearDown(address.dispose);
          final cubit = RequestIdentifierCubit(
            detect: DetectBitcoinStringUsecase(settings: settings),
          );
          addTearDown(cubit.close);
          final request = useBip21
              ? 'bitcoin:$address?amount=0.001'
              : address.toString();

          await cubit.onScanned(request);

          if (environment == Environment.regtest) {
            expect(cubit.state.redirect, RequestIdentifierRedirect.toSend);
            expect(cubit.state.failure, isNull);
          } else {
            expect(cubit.state.redirect, isNull);
            expect(
              cubit.state.failure,
              isA<SendInvalidPaymentRequestFailure>(),
            );
          }
          verify(() => settings.execute()).called(1);
        },
      );
    }
  }
}
