import 'package:bb_mobile/core/exchange/domain/entity/user_summary.dart';
import 'package:bb_mobile/features/recipients/domain/usecases/check_confidential_sepa_eligibility_usecase.dart';
import 'package:flutter_test/flutter_test.dart';

UserSummary _summary(List<String> groups) => UserSummary(
  userNumber: 1,
  groups: groups,
  profile: const UserProfile(firstName: 'Sat', lastName: 'Oshi'),
  email: 'sat@example.com',
  balances: const [],
  dca: const UserDca(isActive: false),
  autoBuy: const UserAutoBuy(
    isActive: false,
    addresses: UserAutoBuyAddresses(),
  ),
);

void main() {
  late CheckConfidentialSepaEligibilityUsecase usecase;

  setUp(() {
    usecase = CheckConfidentialSepaEligibilityUsecase();
  });

  test('allows verified individual EU users', () {
    expect(
      usecase.execute(_summary(['JURI_EU', 'KYC_IDENTITY_VERIFIED'])),
      isTrue,
    );
  });

  test('does not duplicate the EU gate already applied by the flow', () {
    expect(usecase.execute(_summary(['KYC_IDENTITY_VERIFIED'])), isTrue);
  });

  test('rejects users without identity verification', () {
    expect(usecase.execute(_summary(['JURI_EU'])), isFalse);
  });

  test('rejects corporate users', () {
    expect(
      usecase.execute(
        _summary(['JURI_EU', 'KYC_IDENTITY_VERIFIED', 'KYC_IS_CORPORATE']),
      ),
      isFalse,
    );
  });
}
