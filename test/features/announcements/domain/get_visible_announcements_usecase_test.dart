import 'package:bb_mobile/core/entities/signer_entity.dart' show SignerEntity;
import 'package:bb_mobile/core/swaps/domain/entity/auto_swap.dart';
import 'package:bb_mobile/core/swaps/domain/usecases/get_auto_swap_settings_usecase.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/get_wallets_usecase.dart';
import 'package:bb_mobile/features/announcements/domain/entities/announcement.dart';
import 'package:bb_mobile/features/announcements/domain/entities/announcement_dismissal.dart';
import 'package:bb_mobile/features/announcements/domain/repositories/announcement_dismissal_repository.dart';
import 'package:bb_mobile/features/announcements/domain/usecases/get_visible_announcements_usecase.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockGetWalletsUsecase extends Mock implements GetWalletsUsecase {}

class _MockGetAutoSwapSettingsUsecase extends Mock
    implements GetAutoSwapSettingsUsecase {}

class _MockDismissalRepository extends Mock
    implements AnnouncementDismissalRepository {}

Wallet _liquidWallet({required int balanceSat}) => Wallet(
  origin: 'lw1',
  network: Network.liquidMainnet,
  xpubFingerprint: '00000000',
  scriptType: ScriptType.bip84,
  xpub: '',
  externalPublicDescriptor: '',
  internalPublicDescriptor: '',
  signer: SignerEntity.local,
  signerDevice: null,
  balanceSat: BigInt.from(balanceSat),
);

void main() {
  late _MockGetWalletsUsecase getWalletsUsecase;
  late _MockGetAutoSwapSettingsUsecase getAutoSwapSettingsUsecase;
  late _MockDismissalRepository dismissalRepository;
  late GetVisibleAnnouncementsUsecase usecase;

  setUp(() {
    getWalletsUsecase = _MockGetWalletsUsecase();
    getAutoSwapSettingsUsecase = _MockGetAutoSwapSettingsUsecase();
    dismissalRepository = _MockDismissalRepository();
    usecase = GetVisibleAnnouncementsUsecase(
      getWalletsUsecase: getWalletsUsecase,
      getAutoSwapSettingsUsecase: getAutoSwapSettingsUsecase,
      dismissalRepository: dismissalRepository,
    );
  });

  void stub({
    required bool autoswapEnabled,
    required int liquidBalanceSat,
    int triggerBalanceSats = 1000000,
    List<AnnouncementDismissal> dismissals = const [],
  }) {
    when(
      () => getWalletsUsecase.execute(onlyLiquid: true, onlyDefaults: true),
    ).thenAnswer((_) async => [_liquidWallet(balanceSat: liquidBalanceSat)]);
    when(() => getAutoSwapSettingsUsecase.execute()).thenAnswer(
      (_) async => AutoSwap(
        enabled: autoswapEnabled,
        triggerBalanceSats: triggerBalanceSats,
      ),
    );
    when(
      () => dismissalRepository.getDismissals(),
    ).thenAnswer((_) async => dismissals);
  }

  test('shows the autoswap announcement when autoswap is enabled AND the '
      'Liquid balance has reached the trigger threshold', () async {
    stub(autoswapEnabled: true, liquidBalanceSat: 1000000);

    final result = await usecase.execute();

    final list = (result as Ok<List<Announcement>, dynamic>).value;
    expect(list, hasLength(1));
    expect(list.single.id, AnnouncementId.autoswapActive);
  });

  test('hides it when autoswap is enabled but the balance is below the '
      'trigger threshold — no imminent swap to inform about', () async {
    stub(autoswapEnabled: true, liquidBalanceSat: 999999);

    final result = await usecase.execute();

    final list = (result as Ok<List<Announcement>, dynamic>).value;
    expect(list, isEmpty);
  });

  test('hides it when autoswap is disabled, regardless of balance', () async {
    stub(autoswapEnabled: false, liquidBalanceSat: 5000000);

    final result = await usecase.execute();

    final list = (result as Ok<List<Announcement>, dynamic>).value;
    expect(list, isEmpty);
  });

  test('hides it when permanently dismissed', () async {
    stub(
      autoswapEnabled: true,
      liquidBalanceSat: 5000000,
      dismissals: [
        AnnouncementDismissal(
          id: AnnouncementId.autoswapActive,
          dismissedAt: DateTime.utc(2020),
        ),
      ],
    );

    final result = await usecase.execute();

    final list = (result as Ok<List<Announcement>, dynamic>).value;
    expect(list, isEmpty);
  });

  test('the payjoin-privacy announcement is gone from the catalog — payjoin '
      'education lives in settings, never on home (product decision '
      '2026-07-25)', () async {
    stub(autoswapEnabled: true, liquidBalanceSat: 5000000);

    final result = await usecase.execute();

    final list = (result as Ok<List<Announcement>, dynamic>).value;
    expect(
      list.map((a) => a.id),
      isNot(contains(AnnouncementId.payjoinPrivacy)),
    );
  });

  test('an environment with no default liquid wallet is a zero balance, not a '
      'failure — GetWalletsUsecase throws on an empty result, which would '
      'otherwise put an error snackbar on home at every wallet sync', () async {
    when(
      () => getWalletsUsecase.execute(onlyLiquid: true, onlyDefaults: true),
    ).thenThrow(NoWalletsFoundException('no liquid wallet'));
    when(
      () => getAutoSwapSettingsUsecase.execute(),
    ).thenAnswer((_) async => const AutoSwap(enabled: true));
    when(
      () => dismissalRepository.getDismissals(),
    ).thenAnswer((_) async => const []);

    final result = await usecase.execute();

    final list = (result as Ok<List<Announcement>, dynamic>).value;
    expect(list, isEmpty);
  });

  test('returns a failure when a source throws', () async {
    when(
      () => getWalletsUsecase.execute(onlyLiquid: true, onlyDefaults: true),
    ).thenThrow(Exception('boom'));
    when(
      () => getAutoSwapSettingsUsecase.execute(),
    ).thenAnswer((_) async => const AutoSwap(enabled: false));
    when(
      () => dismissalRepository.getDismissals(),
    ).thenAnswer((_) async => const []);

    final result = await usecase.execute();

    expect(result, isA<Err<List<Announcement>, dynamic>>());
  });
}
