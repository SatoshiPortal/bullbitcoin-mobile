import 'dart:async';
import 'dart:convert';

import 'package:bull_ui/app_theme.dart';
import 'package:bull_ui/bull_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:primitives/primitives.dart';
import 'package:secrets/testing.dart';
import 'package:spend/legacy_exceptions.dart';
import 'package:swap_feature/src/domain/entities/swap_wallet.dart';
import 'package:swap_feature/src/presentation/transfer_bloc.dart';
import 'package:swap_feature/src/presentation/transfer_confirm_error.dart';
import 'package:swap_feature/src/swap_l10n.dart';
import 'package:swap_feature/src/ui/pages/swap_confirm_page.dart';
import 'package:swaps/swaps.dart';

class _MockTransferBloc extends Mock implements TransferBloc {}

/// The confirm page shows the app's swap icon, which the app bundles and this
/// member's own test run does not. Serve that one asset as a transparent pixel;
/// any other missing asset still fails.
final class _AppAssets extends CachingAssetBundle {
  static const _swapIcon = 'assets/icons/swap.png';
  static final _pixel = base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNkYAAAAAYAAjCB0C8AAAAASUVORK5CYII=',
  );

  @override
  Future<ByteData> load(String key) async =>
      key == _swapIcon ? ByteData.sublistView(_pixel) : rootBundle.load(key);
}

void main() {
  testWidgets('coin selection failure dismisses the confirmation transition', (
    tester,
  ) async {
    final bloc = _MockTransferBloc();
    final states = StreamController<TransferState>.broadcast();
    addTearDown(states.close);
    final swap = Swap.chain(
      id: 'swap',
      keyIndex: 0,
      type: SwapType.bitcoinToLiquid,
      status: SwapStatus.pending,
      environment: SwapEnvironment.testnet,
      creationTime: DateTime.utc(2026),
      sendWalletId: 'wallet',
      receiveWalletId: 'receive-wallet',
      paymentAddress: 'address',
      paymentAmount: 1000,
    ) as ChainSwap;
    var state = TransferState(
      fromWallet: SwapWallet(
        walletRegistrationForTesting(
          id: 'wallet',
          network: BitcoinNetwork.testnet,
        ),
        BigInt.from(10000),
        false,
      ),
      swap: swap,
      amount: '1000',
    );
    when(() => bloc.state).thenAnswer((_) => state);
    when(() => bloc.canRetryRejectedOrderPayin).thenReturn(false);
    when(() => bloc.stream).thenAnswer((_) => states.stream);
    when(() => bloc.add(const TransferEvent.confirmed())).thenReturn(null);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.themeData(AppThemeType.dark),
        locale: const Locale('en'),
        localizationsDelegates: BullUiLocalizations.localizationsDelegates,
        home: DefaultAssetBundle(
          bundle: _AppAssets(),
          child: MediaQuery(
            data: const MediaQueryData(disableAnimations: true),
            child: BlocProvider<TransferBloc>.value(
              value: bloc,
              child: const SwapConfirmPage(),
            ),
          ),
        ),
      ),
    );
    final copy = swapCopy('en');
    final confirm = tester.widget<BullButton>(
      find.ancestor(
        of: find.text(copy.coreScreensConfirmButton),
        matching: find.byType(BullButton),
      ),
    );
    confirm.onPressed();
    confirm.onPressed();
    await tester.pump();
    verify(() => bloc.add(const TransferEvent.confirmed())).called(1);
    expect(find.byType(BullPaymentTransition), findsOneWidget);

    state = state.copyWith(isConfirming: true);
    states.add(state);
    await tester.pump();
    expect(find.byType(BullPaymentTransition), findsOneWidget);

    state = state.copyWith(
      isConfirming: false,
      txId: '',
      buildTransactionException: BuildTransactionException(
        selectedCoinsUnavailableCode,
      ),
    );
    expect(state.swapFailure, isNull);
    states.add(state);
    await tester.pump();
    await tester.pump();

    expect(find.byType(BullPaymentTransition), findsNothing);
    expect(find.text('View status'), findsNothing);
    expect(find.text(copy.coreScreensConfirmButton), findsOneWidget);
    expect(find.text(copy.sendErrorSelectedCoinsUnavailable), findsOneWidget);
  });
}
