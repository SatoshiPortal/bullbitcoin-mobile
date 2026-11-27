import 'package:bull_ui/app_theme.dart';
import 'package:bb_mobile/features/wallet/domain/wallet_failure.dart';
import 'package:bb_mobile/features/wallet/domain/entity/warning.dart';
import 'package:bb_mobile/features/wallet/presentation/bloc/wallet_bloc.dart';
import 'package:bb_mobile/features/wallet/ui/widgets/home_errors.dart';
import 'package:bb_mobile/localizations.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:backups/backups.dart' show BackupCard;
import 'package:bull_ui/bull_ui.dart' show BullCarousel, BullInfoCard;
import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

class _MockWalletBloc extends MockBloc<WalletEvent, WalletState>
    implements WalletBloc {}

const _serverDown = WalletWarning(
  reason: ElectrumServerDown.bitcoin,
  action: WalletWarningAction.electrumSettings,
  type: WarningType.error,
);

Future<void> _pump(WidgetTester tester, WalletState state) async {
  final bloc = _MockWalletBloc();
  whenListen(bloc, const Stream<WalletState>.empty(), initialState: state);
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.themeData(AppThemeType.light),
      localizationsDelegates: appLocalizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: BlocProvider<WalletBloc>.value(
          value: bloc,
          child: const HomeWarnings(),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('a sync failure reads as stale balances, not a failed load', (
    tester,
  ) async {
    await _pump(
      tester,
      const WalletState(
        status: WalletStatus.success,
        failure: WalletSyncFailure('sync: timeout'),
      ),
    );

    expect(find.textContaining('may be out of date'), findsOneWidget);
    expect(find.textContaining('could not be loaded'), findsNothing);
  });

  testWidgets('a sync failure and a server warning are both shown, swipeable', (
    tester,
  ) async {
    await _pump(
      tester,
      const WalletState(
        status: WalletStatus.success,
        failure: WalletSyncFailure('sync: timeout'),
        warnings: [_serverDown],
      ),
    );

    // The server warning comes first, with its remedy; the stale-balance
    // card is one swipe away rather than hidden.
    final serverCard = find.textContaining('Bitcoin');
    final syncCard = find.textContaining('may be out of date');
    expect(serverCard, findsWidgets);
    expect(syncCard, findsOneWidget);
    expect(find.byType(BullCarousel), findsOneWidget);

    final screen = tester.getRect(find.byType(BullCarousel));
    expect(screen.overlaps(tester.getRect(serverCard.first)), isTrue);
    expect(screen.overlaps(tester.getRect(syncCard)), isFalse);

    await tester.drag(find.byType(BullCarousel), const Offset(-500, 0));
    await tester.pumpAndSettle();

    expect(screen.overlaps(tester.getRect(syncCard)), isTrue);
  });

  testWidgets('a failed load is still reported', (tester) async {
    await _pump(
      tester,
      const WalletState(
        status: WalletStatus.failure,
        failure: WalletStorageFailure('read failed'),
      ),
    );

    expect(find.textContaining('could not be loaded'), findsOneWidget);
  });

  testWidgets('network then swap then load; backup is not in the carousel', (
    tester,
  ) async {
    await _pump(
      tester,
      const WalletState(
        backupNeeded: true,
        swapServerUnreachable: true,
        warnings: [_serverDown],
        status: WalletStatus.failure,
        failure: WalletStorageFailure('read failed'),
      ),
    );
    final carousel = tester.widget<BullCarousel>(find.byType(BullCarousel));
    final cards = carousel.children
        .cast<ConstrainedBox>()
        .map((box) => box.child as BullInfoCard)
        .toList();
    final l10n = AppLocalizations.of(tester.element(find.byType(BullCarousel)));
    expect(cards.map((card) => card.title), [
      l10n.walletWarningElectrumBitcoinDown,
      l10n.walletWarningSwapServerUnreachable,
      contains('could not be loaded'),
    ]);
    expect(cards.map((card) => card.onTap != null), [true, true, false]);
    expect(find.byType(BackupCard), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(BullCarousel),
        matching: find.byType(BackupCard),
      ),
      findsNothing,
    );
  });
}
