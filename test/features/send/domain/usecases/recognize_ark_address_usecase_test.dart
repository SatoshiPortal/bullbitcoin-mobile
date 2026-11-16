import 'dart:async';

import 'package:ark/ark.dart';
import 'package:bb_mobile/features/send/domain/send_failure.dart';
import 'package:bb_mobile/features/send/domain/usecases/recognize_ark_address_usecase.dart';
import 'package:bb_mobile/features/send/presentation/send_ark_cubit.dart';
import 'package:bull_ark/bull_ark.dart'
    show ArkFacade, ArkFailure, ArkFeatureStorageFailure;
import 'package:bull_ark/ark_setup.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:primitives/primitives.dart';

class Client extends Mock implements ArkClient {}

class Registry extends Mock implements ArkAccountRegistryRepository {}

class Preferences extends Mock implements ArkPreferencesRepository {}

class Provisioning extends Mock implements ArkProvisioningPort {}

class Fixture {
  final client = Client();
  final registry = Registry();
  final preferences = Preferences();
  late final ArkFacade facade = createArkFacade(
    client: client,
    preferences: preferences,
    registry: registry,
    provisioning: Provisioning(),
  );
}

const mainnetAddress =
    'ark1pwh9vsmezqqpharv69q4z8m6x364d5m5prnmcalcalq9pdmzw0y7mpveck4pcfhezqypczkrrj3lkx5ue4qrf4jc7ztpt9htdttmh2judhqnu7aue8p0y9mqkr4cf5';

// Classifier-only regtest HRP/checksum fixture; not native payment validity.
const address =
    'tark1pwh9vsmezqqpharv69q4z8m6x364d5m5prnmcalcalq9pdmzw0y7mpveck4pcfhezqypczkrrj3lkx5ue4qrf4jc7ztpt9htdttmh2judhqnu7aue8p0y9mq47jn9z';
void main() {
  final account = ArkAccountId(
    parent: Fingerprint('00112233'),
    network: BitcoinNetwork.regtest,
    serverIdentity: 'server',
  );
  final config = ArkAccountConfig(
    id: account,
    arkUrl: Uri.parse('https://ark.second.tech'),
    primaryEsploraUrl: Uri.parse('https://example.com'),
  );
  test(
    'ordinary BIP21 paste does not consult Ark or alter its send path',
    () async {
      final fixture = Fixture();
      final facade = fixture.facade;
      final result = await RecognizeArkAddressUsecase(facade).execute(
        input: 'bitcoin:bc1qexample?amount=0.01',
        network: BitcoinNetwork.regtest,
        restricted: false,
      );
      expect(
        result,
        isA<Ok<SendArkRequest?, SendFailure>>().having(
          (r) => r.value,
          'non Ark',
          isNull,
        ),
      );
      verifyZeroInteractions(fixture.registry);
      verifyZeroInteractions(fixture.client);
    },
  );
  test('Ark paste consults only public local account inventory', () async {
    final fixture = Fixture();
    final facade = fixture.facade;
    when(() => fixture.registry.list()).thenAnswer((_) async => Ok([config]));
    when(() => fixture.preferences.isEnabled(account))
        .thenAnswer((_) async => const Ok(true));
    final result = await RecognizeArkAddressUsecase(facade).execute(
      input: ' $address ',
      network: BitcoinNetwork.regtest,
      restricted: false,
    );
    expect(
      result,
      isA<Ok<SendArkRequest?, SendFailure>>()
          .having((r) => r.value?.accounts, 'eligible account', [account])
          .having((r) => r.value?.destination, 'trimmed destination', address),
    );
    verify(() => fixture.registry.list()).called(1);
    verifyZeroInteractions(fixture.client);
  });
  test('coin selection sweep and multi recipient restrictions refuse before inventory', () async {
    final fixture = Fixture();
    final facade = fixture.facade;
    expect(
      await RecognizeArkAddressUsecase(facade).execute(
        input: address,
        network: BitcoinNetwork.regtest,
        restricted: true,
      ),
      isA<Err>(),
    );
    verifyZeroInteractions(fixture.registry);
    verifyZeroInteractions(fixture.client);
  });
  test('off or missing integration is an explicit unavailable route', () async {
    final fixture = Fixture();
    final facade = fixture.facade;
    when(() => fixture.registry.list()).thenAnswer((_) async => const Ok([]));
    for (final configured in <ArkFacade?>[facade, null]) {
      expect(
        await RecognizeArkAddressUsecase(configured).execute(
          input: address,
          network: BitcoinNetwork.regtest,
          restricted: false,
        ),
        isA<Err<SendArkRequest?, SendFailure>>().having(
          (r) => r.failure,
          'unavailable',
          isA<SendArkRouteUnavailableFailure>(),
        ),
      );
    }
  });
  test('paste never requests quote read receive or submit', () async {
    final fixture = Fixture();
    final facade = fixture.facade;
    when(() => fixture.registry.list())
        .thenAnswer((_) async => const Err(ArkFeatureStorageFailure()));
    expect(
      await RecognizeArkAddressUsecase(facade).execute(
        input: address,
        network: LiquidNetwork.regtest,
        restricted: false,
      ),
      isA<Err>(),
    );
    verify(() => fixture.registry.list()).called(1);
    verifyZeroInteractions(fixture.client);
  });
  test(
    'late local account response cannot revive an older pasted recipient',
    () async {
      final fixture = Fixture();
      final facade = fixture.facade;
      final pending = Completer<Result<List<ArkAccountConfig>, ArkFailure>>();
      when(() => fixture.registry.list()).thenAnswer((_) => pending.future);
      final cubit = SendArkCubit(RecognizeArkAddressUsecase(facade));
      when(() => fixture.preferences.isEnabled(account))
          .thenAnswer((_) async => const Ok(true));
      final first = cubit.resolve(
        input: address,
        network: BitcoinNetwork.regtest,
        coinControl: false,
        sweep: false,
        silentPayments: false,
        multipleRecipients: false,
      );
      expect(cubit.state, isA<SendArkLoading>());
      await cubit.resolve(
        input: 'bitcoin:bc1qexample',
        network: BitcoinNetwork.regtest,
        coinControl: false,
        sweep: false,
        silentPayments: false,
        multipleRecipients: false,
      );
      expect(cubit.state, isA<SendArkHidden>());
      pending.complete(Ok([config]));
      await first;
      expect(cubit.state, isA<SendArkHidden>());
      await cubit.close();
    },
  );
  test('mainnet Ark paste is recognized but gated before inventory or native access', () async {
    final fixture = Fixture();
    final usecase = RecognizeArkAddressUsecase(fixture.facade);
    expect(usecase.recognizes(mainnetAddress, BitcoinNetwork.mainnet), true);
    expect(
      await usecase.execute(
        input: mainnetAddress,
        network: BitcoinNetwork.mainnet,
        restricted: false,
      ),
      isA<Err<SendArkRequest?, SendFailure>>().having(
        (r) => r.failure,
        'gated',
        isA<SendArkRouteUnavailableFailure>(),
      ),
    );
    verifyZeroInteractions(fixture.registry);
    verifyZeroInteractions(fixture.preferences);
    verifyZeroInteractions(fixture.client);
  });
}
