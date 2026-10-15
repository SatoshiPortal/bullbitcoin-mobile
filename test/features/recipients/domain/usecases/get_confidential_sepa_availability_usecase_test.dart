import 'package:bb_mobile/core/exchange/domain/entity/user_summary.dart';
import 'package:bb_mobile/core/exchange/domain/usecases/get_exchange_user_summary_usecase.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/recipients/application/usecases/get_recipients_environment_usecase.dart';
import 'package:bb_mobile/features/recipients/domain/entities/virtual_iban.dart';
import 'package:bb_mobile/features/recipients/domain/recipients_failure.dart';
import 'package:bb_mobile/features/recipients/domain/repositories/virtual_iban_repository.dart';
import 'package:bb_mobile/features/recipients/domain/usecases/get_confidential_sepa_availability_usecase.dart';
import 'package:bb_mobile/features/recipients/domain/value_objects/confidential_sepa_availability.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockGetExchangeUserSummaryUsecase extends Mock
    implements GetExchangeUserSummaryUsecase {}

class _MockVirtualIbanRepository extends Mock
    implements VirtualIbanRepository {}

class _MockGetRecipientsEnvironmentUsecase extends Mock
    implements GetRecipientsEnvironmentUsecase {}

const _eligibleGroups = ['KYC_IDENTITY_VERIFIED', 'JURI_EU'];

UserSummary _summaryWith(List<String> groups) => UserSummary(
  userNumber: 1,
  groups: groups,
  profile: const UserProfile(firstName: 'Satoshi', lastName: 'Nakamoto'),
  email: 'satoshi@example.com',
  balances: const [],
  currency: 'EUR',
  dca: const UserDca(isActive: false),
  autoBuy: const UserAutoBuy(
    isActive: false,
    addresses: UserAutoBuyAddresses(),
  ),
);

void main() {
  late _MockGetExchangeUserSummaryUsecase summary;
  late _MockVirtualIbanRepository virtualIbans;
  late _MockGetRecipientsEnvironmentUsecase environment;

  setUp(() {
    summary = _MockGetExchangeUserSummaryUsecase();
    virtualIbans = _MockVirtualIbanRepository();
    environment = _MockGetRecipientsEnvironmentUsecase();
    when(
      () => environment.execute(),
    ).thenAnswer((_) async => const Ok(Environment.mainnet));
  });

  Future<Result<ConfidentialSepaAvailability, RecipientsFailure>> run({
    List<String> groups = _eligibleGroups,
    Result<VirtualIban?, RecipientsFailure> virtualIban = const Ok(null),
  }) {
    when(() => summary.execute()).thenAnswer((_) async => _summaryWith(groups));
    when(
      () => virtualIbans.find(isTestnet: any(named: 'isTestnet')),
    ).thenAnswer((_) async => virtualIban);
    return GetConfidentialSepaAvailabilityUsecase(
      getExchangeUserSummaryUsecase: summary,
      virtualIbanRepository: virtualIbans,
      getRecipientsEnvironmentUsecase: environment,
    ).execute();
  }

  ConfidentialSepaAvailability availability(
    Result<ConfidentialSepaAvailability, RecipientsFailure> result,
  ) => (result as Ok<ConfidentialSepaAvailability, RecipientsFailure>).value;

  group('an account that cannot use Confidential SEPA', () {
    for (final (name, groups) in [
      ('outside the EU', ['KYC_IDENTITY_VERIFIED']),
      ('corporate', [..._eligibleGroups, 'KYC_IS_CORPORATE']),
      ('with a lighter KYC level', ['KYC_LIGHT_VERIFICATION', 'JURI_EU']),
    ]) {
      test(name, () async {
        expect(
          availability(await run(groups: groups)),
          ConfidentialSepaAvailability.unavailable,
        );
        verifyNever(
          () => virtualIbans.find(isTestnet: any(named: 'isTestnet')),
        );
      });
    }
  });

  test('an eligible user without a virtual IBAN needs one', () async {
    expect(
      availability(await run()),
      ConfidentialSepaAvailability.needsVirtualIban,
    );
  });

  test('a virtual IBAN that is still pending is not ready', () async {
    expect(
      availability(await run(virtualIban: const Ok(PendingVirtualIban()))),
      ConfidentialSepaAvailability.needsVirtualIban,
    );
  });

  test('an active virtual IBAN makes it ready', () async {
    final active = VirtualIban.fromBankDetails(
      iban: 'FR7616958000016918327146718',
      bicCode: 'FIRPFRP2',
      bankAddress: '1 Rue de la Paix, Paris',
    );

    expect(
      availability(await run(virtualIban: Ok(active))),
      ConfidentialSepaAvailability.ready,
    );
  });

  test('an unreadable user summary is a failure', () async {
    when(() => summary.execute()).thenThrow(Exception('401 unauthenticated'));

    final result = await GetConfidentialSepaAvailabilityUsecase(
      getExchangeUserSummaryUsecase: summary,
      virtualIbanRepository: virtualIbans,
      getRecipientsEnvironmentUsecase: environment,
    ).execute();

    expect(result, isA<Err<ConfidentialSepaAvailability, RecipientsFailure>>());
  });

  test('a failed virtual IBAN lookup is a failure', () async {
    final result = await run(
      virtualIban: const Err(RecipientsNetworkFailure()),
    );

    expect(
      (result as Err<ConfidentialSepaAvailability, RecipientsFailure>).failure,
      isA<RecipientsNetworkFailure>(),
    );
  });
}
