import 'dart:async';

import 'package:bull_ui/bull_ui.dart'
    show
        BullButton,
        BullFadingLinearProgress,
        BullFieldAction,
        BullIcon,
        bullUiLocalizationsDelegate;
import 'package:bull_ui/testing.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:primitives/primitives.dart';
import 'package:settings/settings.dart';
import 'package:settings/src/wallet_details/domain/delete_wallet_usecase.dart';
import 'package:settings/src/wallet_details/domain/discover_wallet_usecase.dart';
import 'package:settings/src/wallet_details/domain/read_wallet_details_usecase.dart';
import 'package:settings/src/wallet_details/domain/wallet_details.dart';
import 'package:settings/src/wallet_details/domain/wallet_details_failure.dart';
import 'package:settings/src/wallet_details/presentation/wallet_details_cubit.dart';
import 'package:settings/src/wallet_details/presentation/wallet_discovery_cubit.dart';
import 'package:settings/src/wallet_details/ui/wallet_details_screen.dart';

class _MockReadWalletDetails extends Mock implements ReadWalletDetailsUsecase {}

class _MockDeleteWallet extends Mock implements DeleteWalletUsecase {}

const _walletId = 'wpkh([0a1b2c3d/84h/0h/0h])';

WalletDetails _details({bool isDefault = false, String? label = 'Savings'}) =>
    WalletDetails(
      id: _walletId,
      label: label,
      isDefault: isDefault,
      network: BitcoinNetwork.mainnet,
      scriptType: ScriptType.bip84,
      masterFingerprint: '0a1b2c3d',
      xpub: 'xpub-marker',
      externalDescriptor: 'wpkh([0a1b2c3d/84h/0h/0h]xpub-marker/0/*)',
      signer: SignerEntity.none,
      signerDevice: null,
    );

void main() {
  late SettingsLocalizations loc;
  late List<bool> deleted;

  setUp(() async {
    loc = await SettingsLocalizations.delegate.load(const Locale('en'));
    deleted = [];
  });

  testWidgets('shows the wallet information and ends with Addresses', (
    tester,
  ) async {
    await _pump(tester);

    expect(find.text('Savings'), findsOneWidget);
    expect(find.text('0a1b2c3d'), findsOneWidget);
    expect(find.text('xpub-marker'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text(loc.addressViewAddressesTitle),
      100,
    );
    expect(find.text(loc.walletDiscoveryButton), findsOneWidget);
    expect(find.text(loc.addressViewAddressesTitle), findsOneWidget);
  });

  testWidgets('names a default wallet by its network', (tester) async {
    await _pump(tester, details: _details(isDefault: true, label: null));

    expect(find.text(loc.globalDefaultBitcoinWalletLabel), findsOneWidget);
  });

  testWidgets('falls back to the wallet id when it has no label', (
    tester,
  ) async {
    await _pump(tester, details: _details(label: null));

    expect(find.text(_walletId), findsOneWidget);
  });

  testWidgets('only offers wallet deletion for a non-default wallet', (
    tester,
  ) async {
    await _pump(tester, details: _details(isDefault: true));
    expect(find.byType(BullIcon), findsNothing);
    expect(find.byTooltip(loc.walletDeletionConfirmationTitle), findsNothing);

    await _pump(tester, details: _details());
    expect(find.byType(BullIcon), findsOneWidget);
    expect(find.byTooltip(loc.walletDeletionConfirmationTitle), findsOneWidget);
  });

  testWidgets('names the delete wallet button and exposes its state', (
    tester,
  ) async {
    await _pump(tester);
    final semantics = tester.ensureSemantics();
    try {
      final button = find.ancestor(
        of: find.byTooltip(loc.walletDeletionConfirmationTitle),
        matching: find.byType(IconButton),
      );
      expect(
        tester.getSemantics(button),
        containsSemantics(
          tooltip: loc.walletDeletionConfirmationTitle,
          isButton: true,
          hasTapAction: true,
          isEnabled: true,
        ),
      );
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('names each copy button with the translated Copy label', (
    tester,
  ) async {
    await _pump(tester);
    final semantics = tester.ensureSemantics();
    try {
      final buttons = find.ancestor(
        of: find.byIcon(Icons.copy_sharp),
        matching: find.byType(BullFieldAction),
      );
      expect(buttons, findsNWidgets(2));
      expect(find.byTooltip(loc.copyDialogButton), findsNWidgets(2));
      for (var index = 0; index < 2; index++) {
        final node = tester.getSemantics(buttons.at(index));
        expect(node.label.split('\n').last, loc.copyDialogButton);
        expect(node, containsSemantics(isButton: true, hasTapAction: true));
      }
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('confirms a copied public key with a toast', (tester) async {
    final copied = <Object?>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') copied.add(call.arguments);
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    await _pump(tester);

    await tester.tap(find.byIcon(Icons.copy_sharp).first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(copied, [
      {'text': 'xpub-marker'},
    ]);
    expect(find.text(loc.copiedToClipboard), findsOneWidget);

    // The toast dismisses itself on a timer; let it run out.
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
  });

  testWidgets('shows progress while the wallet is being read', (tester) async {
    final read = _MockReadWalletDetails();
    final gate = Completer<Result<WalletDetails, WalletDetailsFailure>>();
    when(() => read.execute(any())).thenAnswer((_) => gate.future);
    final cubit = WalletDetailsCubit(read, _MockDeleteWallet());
    addTearDown(cubit.close);
    unawaited(cubit.load(_walletId));

    await _mount(
      tester,
      cubit: cubit,
      discovery: _discovery(),
      onDeleted: () {},
      settle: false,
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text(loc.walletDetailsUnnamedWalletFallback), findsOneWidget);

    gate.complete(Ok(_details()));
    await tester.pumpAndSettle();
    expect(find.text('Savings'), findsOneWidget);
  });

  testWidgets('reports a wallet that cannot be read', (tester) async {
    await _pump(tester, readResult: const Err(WalletDetailsNotFoundFailure()));

    expect(find.text(loc.walletDeletionErrorWalletNotFound), findsOneWidget);
  });

  testWidgets('confirms before deleting and leaves once it is committed', (
    tester,
  ) async {
    final gate = Completer<Result<void, WalletDetailsFailure>>();
    final screen = await _pump(
      tester,
      onDelete: () => gate.future,
      onDeleted: () => deleted.add(true),
    );

    await tester.tap(find.byTooltip(loc.walletDeletionConfirmationTitle));
    await tester.pumpAndSettle();
    expect(find.text(loc.walletDeletionConfirmationMessage), findsOneWidget);

    await tester.tap(find.text(loc.walletDeletionConfirmationDeleteButton));
    await tester.pump();
    expect(find.text(loc.walletDetailsDeletingMessage), findsOneWidget);
    expect(
      tester
          .widget<IconButton>(
            find.ancestor(
              of: find.byTooltip(loc.walletDeletionConfirmationTitle),
              matching: find.byType(IconButton),
            ),
          )
          .onPressed,
      isNull,
      reason: 'a running deletion cannot be started twice',
    );

    gate.complete(const Ok(null));
    await tester.pump();
    expect(deleted, [true]);
    verify(() => screen.delete.execute(_walletId)).called(1);
  });

  testWidgets('cancelling the confirmation keeps the wallet', (tester) async {
    final screen = await _pump(tester);

    await tester.tap(find.byTooltip(loc.walletDeletionConfirmationTitle));
    await tester.pumpAndSettle();
    await tester.tap(find.text(loc.walletDeletionConfirmationCancelButton));
    await tester.pumpAndSettle();

    expect(find.text(loc.walletDeletionConfirmationMessage), findsNothing);
    expect(find.text('Savings'), findsOneWidget);
    verifyNever(() => screen.delete.execute(any()));
  });

  testWidgets('reports the reason a deletion was refused', (tester) async {
    await _pump(
      tester,
      onDelete: () async => const Err(WalletDetailsOngoingSwapsFailure()),
    );

    await tester.tap(find.byTooltip(loc.walletDeletionConfirmationTitle));
    await tester.pumpAndSettle();
    await tester.tap(find.text(loc.walletDeletionConfirmationDeleteButton));
    await tester.pumpAndSettle();

    expect(find.text(loc.walletDeletionFailedTitle), findsOneWidget);
    expect(find.text(loc.walletDeletionErrorOngoingSwaps), findsOneWidget);

    await tester.tap(find.text(loc.walletDeletionFailedOkButton));
    await tester.pumpAndSettle();
    expect(find.text(loc.walletDeletionFailedTitle), findsNothing);
    expect(find.text('Savings'), findsOneWidget);
    expect(deleted, isEmpty);
  });

  testWidgets('runs the scan from the button and reports its outcome', (
    tester,
  ) async {
    final gate = Completer<Result<void, WalletDetailsFailure>>();
    await _pump(tester, onDiscover: (_) => gate.future);
    await _revealBottom(tester);

    await tester.tap(find.text(loc.walletDiscoveryButton));
    await tester.pump();
    final button = find.widgetWithText(BullButton, loc.walletDiscoveryButton);
    expect(tester.widget<BullButton>(button).disabled, isTrue);
    expect(
      tester
          .widget<BullFadingLinearProgress>(
            find.byType(BullFadingLinearProgress),
          )
          .trigger,
      isTrue,
    );

    gate.complete(const Ok(null));
    await tester.pumpAndSettle();
    expect(tester.widget<BullButton>(button).disabled, isFalse);
    expect(find.text(loc.walletDiscoverySucceeded), findsOneWidget);
  });

  testWidgets('reports a scan the wallet could not complete', (tester) async {
    await _pump(
      tester,
      onDiscover: (_) async => const Err(WalletDetailsDiscoveryFailure()),
    );
    await _revealBottom(tester);

    await tester.tap(find.text(loc.walletDiscoveryButton));
    await tester.pumpAndSettle();

    expect(find.text(loc.walletDiscoveryFailed), findsOneWidget);
  });
}

WalletDiscoveryCubit _discovery([
  Future<Result<void, WalletDetailsFailure>> Function(String walletId)?
  discover,
]) => WalletDiscoveryCubit(
  DiscoverWalletUsecase(discover ?? (_) async => const Ok(null)),
);

/// Scrolls the details list to its last rows. The list is taller than the
/// phone-sized viewport the tests use, so the scan button is only reachable
/// once scrolled to.
Future<void> _revealBottom(WidgetTester tester) async {
  await tester.drag(find.byType(ListView), const Offset(0, -400));
  await tester.pumpAndSettle();
}

Future<({WalletDetailsCubit cubit, _MockDeleteWallet delete})> _pump(
  WidgetTester tester, {
  WalletDetails? details,
  Result<WalletDetails, WalletDetailsFailure>? readResult,
  Future<Result<void, WalletDetailsFailure>> Function()? onDelete,
  Future<Result<void, WalletDetailsFailure>> Function(String walletId)?
  onDiscover,
  void Function()? onDeleted,
  bool settle = true,
}) async {
  final reader = _MockReadWalletDetails();
  when(() => reader.execute(any()))
      .thenAnswer((_) async => readResult ?? Ok(details ?? _details()));
  final delete = _MockDeleteWallet();
  final respond = onDelete ?? () async => const Ok(null);
  when(() => delete.execute(any())).thenAnswer((_) => respond());
  final cubit = WalletDetailsCubit(reader, delete);
  addTearDown(cubit.close);
  await cubit.load(_walletId);
  await _mount(
    tester,
    cubit: cubit,
    discovery: _discovery(onDiscover),
    onDeleted: onDeleted ?? () {},
    settle: settle,
  );
  return (cubit: cubit, delete: delete);
}

Future<void> _mount(
  WidgetTester tester, {
  required WalletDetailsCubit cubit,
  required WalletDiscoveryCubit discovery,
  required void Function() onDeleted,
  bool settle = true,
}) async {
  addTearDown(discovery.close);
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (_, _) => MultiBlocProvider(
          providers: [
            BlocProvider<WalletDetailsCubit>.value(value: cubit),
            BlocProvider<WalletDiscoveryCubit>.value(value: discovery),
          ],
          child: WalletDetailsScreen(onDeleted: (_) => onDeleted()),
        ),
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    MaterialApp.router(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        extensions: testBullExtensions,
        textTheme: testBullTypography.toTextTheme(),
      ),
      localizationsDelegates: const [
        bullUiLocalizationsDelegate,
        ...SettingsLocalizations.localizationsDelegates,
      ],
      supportedLocales: SettingsLocalizations.supportedLocales,
      routerConfig: router,
    ),
  );
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
  }
}
