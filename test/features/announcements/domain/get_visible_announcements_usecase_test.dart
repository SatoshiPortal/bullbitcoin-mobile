import 'package:bb_mobile/core/settings/domain/repositories/settings_repository.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/swaps/domain/entity/auto_swap.dart';
import 'package:bb_mobile/core/swaps/domain/usecases/get_auto_swap_settings_usecase.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_transaction.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/get_wallet_transactions_usecase.dart';
import 'package:bb_mobile/features/announcements/domain/entities/announcement.dart';
import 'package:bb_mobile/features/announcements/domain/entities/announcement_dismissal.dart';
import 'package:bb_mobile/features/announcements/domain/get_visible_announcements_usecase.dart';
import 'package:bb_mobile/features/announcements/domain/repositories/announcement_dismissal_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockSettingsRepository extends Mock implements SettingsRepository {}

class _MockGetWalletTransactionsUsecase extends Mock
    implements GetWalletTransactionsUsecase {}

class _MockGetAutoSwapSettingsUsecase extends Mock
    implements GetAutoSwapSettingsUsecase {}

class _MockDismissalRepository extends Mock
    implements AnnouncementDismissalRepository {}

WalletTransaction _tx() => const WalletTransaction(
  walletId: 'w1',
  network: Network.bitcoinMainnet,
  direction: WalletTransactionDirection.incoming,
  status: WalletTransactionStatus.confirmed,
  txId: 'txid',
  amountSat: 1000,
  feeSat: 100,
  vsize: 110,
  inputs: [],
  outputs: [],
  isRbf: false,
);

SettingsEntity _settings({required bool payjoinEnabled}) => SettingsEntity(
  environment: Environment.mainnet,
  bitcoinUnit: BitcoinUnit.btc,
  currencyCode: 'USD',
  isPayjoinEnabled: payjoinEnabled,
);

void main() {
  late _MockSettingsRepository settingsRepository;
  late _MockGetWalletTransactionsUsecase getWalletTransactionsUsecase;
  late _MockGetAutoSwapSettingsUsecase getAutoSwapSettingsUsecase;
  late _MockDismissalRepository dismissalRepository;
  late GetVisibleAnnouncementsUsecase usecase;

  setUp(() {
    settingsRepository = _MockSettingsRepository();
    getWalletTransactionsUsecase = _MockGetWalletTransactionsUsecase();
    getAutoSwapSettingsUsecase = _MockGetAutoSwapSettingsUsecase();
    dismissalRepository = _MockDismissalRepository();
    usecase = GetVisibleAnnouncementsUsecase(
      settingsRepository: settingsRepository,
      getWalletTransactionsUsecase: getWalletTransactionsUsecase,
      getAutoSwapSettingsUsecase: getAutoSwapSettingsUsecase,
      dismissalRepository: dismissalRepository,
    );
  });

  void stub({
    required bool payjoinEnabled,
    required bool hasHistory,
    bool autoswapEnabled = false,
    List<AnnouncementDismissal> dismissals = const [],
  }) {
    when(
      () => settingsRepository.fetch(),
    ).thenAnswer((_) async => _settings(payjoinEnabled: payjoinEnabled));
    when(
      () => getWalletTransactionsUsecase.execute(),
    ).thenAnswer((_) async => hasHistory ? [_tx()] : <WalletTransaction>[]);
    when(
      () => getAutoSwapSettingsUsecase.execute(),
    ).thenAnswer((_) async => AutoSwap(enabled: autoswapEnabled));
    when(
      () => dismissalRepository.getDismissals(),
    ).thenAnswer((_) async => dismissals);
  }

  test('shows the payjoin-privacy announcement when there is history and '
      'payjoin is disabled', () async {
    stub(payjoinEnabled: false, hasHistory: true);

    final result = await usecase.execute();

    final list = (result as Ok<List<Announcement>, dynamic>).value;
    expect(list, hasLength(1));
    expect(list.single.id, AnnouncementId.payjoinPrivacy);
  });

  test('hides it when payjoin is already enabled', () async {
    stub(payjoinEnabled: true, hasHistory: true);

    final result = await usecase.execute();

    final list = (result as Ok<List<Announcement>, dynamic>).value;
    expect(list, isEmpty);
  });

  test('hides it when the wallet has no transaction history', () async {
    stub(payjoinEnabled: false, hasHistory: false);

    final result = await usecase.execute();

    final list = (result as Ok<List<Announcement>, dynamic>).value;
    expect(list, isEmpty);
  });

  test('hides it when permanently dismissed', () async {
    stub(
      payjoinEnabled: false,
      hasHistory: true,
      dismissals: [
        AnnouncementDismissal(
          id: AnnouncementId.payjoinPrivacy,
          dismissedAt: DateTime(2020),
        ),
      ],
    );

    final result = await usecase.execute();

    final list = (result as Ok<List<Announcement>, dynamic>).value;
    expect(list, isEmpty);
  });

  test('shows the autoswap announcement when autoswap is enabled', () async {
    stub(payjoinEnabled: true, hasHistory: false, autoswapEnabled: true);

    final result = await usecase.execute();

    final list = (result as Ok<List<Announcement>, dynamic>).value;
    expect(list, hasLength(1));
    expect(list.single.id, AnnouncementId.autoswapActive);
  });

  test('shows both announcements, ordered by priority', () async {
    stub(payjoinEnabled: false, hasHistory: true, autoswapEnabled: true);

    final result = await usecase.execute();

    final list = (result as Ok<List<Announcement>, dynamic>).value;
    expect(list.map((a) => a.id), [
      AnnouncementId.payjoinPrivacy,
      AnnouncementId.autoswapActive,
    ]);
  });

  test('returns a storage failure when a source throws', () async {
    when(() => settingsRepository.fetch()).thenThrow(Exception('boom'));
    when(
      () => getWalletTransactionsUsecase.execute(),
    ).thenAnswer((_) async => <WalletTransaction>[]);
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
