import 'package:primitives/primitives.dart' show ScriptType;
import 'package:bull_ui/bull_ui.dart'
    show BullAmountInput, bullUiLocalizationsDelegate;

import 'dart:async';

import 'package:primitives/primitives.dart' show SignerEntity;
import 'package:bb_mobile/core/errors/send_errors.dart';
import 'package:bull_ui/app_theme.dart';
import 'package:bb_mobile/features/swap/presentation/transfer_bloc.dart';
import 'package:bb_mobile/features/swap/ui/pages/swap_page.dart';
import 'package:bb_mobile/features/wallet/domain/wallet.dart';
import 'package:bb_mobile/localizations.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';

class _MockTransferBloc extends Mock implements TransferBloc {}

final _wallet = Wallet(
  origin: 'wallet-1',
  network: Network.bitcoinTestnet,
  xpubFingerprint: 'fingerprint',
  scriptType: ScriptType.bip84,
  xpub: 'xpub',
  externalPublicDescriptor: 'external',
  internalPublicDescriptor: 'internal',
  signer: SignerEntity.local,
  signerDevice: null,
  balanceSat: BigInt.from(100000),
);

void main() {
  Future<Rect> continueRect(WidgetTester tester, TransferState state) async {
    final bloc = _MockTransferBloc();
    when(() => bloc.state).thenReturn(state);
    when(() => bloc.stream).thenAnswer((_) => const Stream.empty());

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.themeData(AppThemeType.light),
        localizationsDelegates: const [
          bullUiLocalizationsDelegate,
          ...appLocalizationsDelegates,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: BlocProvider<TransferBloc>.value(
          value: bloc,
          child: const SwapPage(),
        ),
      ),
    );
    await tester.pump();

    return tester.getRect(find.text('Continue'));
  }

  testWidgets('Continue stays pinned at the bottom whatever is toggled', (
    tester,
  ) async {
    final internal = await continueRect(
      tester,
      TransferState(fromWallet: _wallet),
    );
    final external = await continueRect(
      tester,
      TransferState(fromWallet: _wallet, sendToExternal: true),
    );
    final consolidating = await continueRect(
      tester,
      TransferState(fromWallet: _wallet, consolidationRequired: true),
    );

    expect(external, internal);
    expect(consolidating, internal);
    final screenHeight =
        tester.view.physicalSize.height / tester.view.devicePixelRatio;
    expect(internal.bottom, greaterThan(screenHeight - 100));
  });

  testWidgets('a very short viewport scrolls the actions with the form', (
    tester,
  ) async {
    // Only the height is short: the test font is wider than real glyphs.
    tester.view.physicalSize = const Size(800, 200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await continueRect(tester, TransferState(fromWallet: _wallet));
    expect(tester.takeException(), isNull);

    final continueButton = find.text('Continue');
    await tester.scrollUntilVisible(
      continueButton,
      100,
      scrollable: find.byType(Scrollable).first,
    );
    expect(tester.takeException(), isNull);
    expect(tester.getRect(continueButton).bottom, lessThanOrEqualTo(200));
  });

  testWidgets('a swap creation error scrolls into view above the actions', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final states = StreamController<TransferState>.broadcast();
    addTearDown(states.close);
    final initial = TransferState(
      fromWallet: _wallet,
      consolidationRequired: true,
    );
    final bloc = _MockTransferBloc();
    when(() => bloc.state).thenReturn(initial);
    when(() => bloc.stream).thenAnswer((_) => states.stream);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.themeData(AppThemeType.light),
        localizationsDelegates: const [
          bullUiLocalizationsDelegate,
          ...appLocalizationsDelegates,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: BlocProvider<TransferBloc>.value(
          value: bloc,
          child: const SwapPage(),
        ),
      ),
    );
    await tester.pump();

    final failed = initial.copyWith(
      swapCreationException: InsufficientFundsSwapException(),
    );
    when(() => bloc.state).thenReturn(failed);
    states.add(failed);
    // Build the error, start the scroll after that frame, then finish it.
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    final error = tester.getRect(find.text('Insufficient Funds'));
    final actions = tester.getRect(find.text('Continue'));
    expect(error.bottom, lessThanOrEqualTo(actions.top));
  });

  testWidgets('the amount cannot be edited while the swap is created', (
    tester,
  ) async {
    await continueRect(
      tester,
      TransferState(fromWallet: _wallet, isCreatingSwap: true),
    );
    expect(
      tester.widget<BullAmountInput>(find.byType(BullAmountInput)).readOnly,
      isTrue,
    );
  });
}
