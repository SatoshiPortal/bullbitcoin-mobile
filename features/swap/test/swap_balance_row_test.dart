import 'package:bull_ui/app_theme.dart';
import 'package:bull_ui/bull_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:primitives/primitives.dart';
import 'package:secrets/testing.dart';
import 'package:swap_feature/src/domain/entities/swap_wallet.dart';
import 'package:swap_feature/src/presentation/transfer_bloc.dart';
import 'package:swap_feature/src/swap_l10n.dart';
import 'package:swap_feature/src/ui/widgets/swap_balance_row.dart';

class _MockTransferBloc extends Mock implements TransferBloc {}

void main() {
  final noBalance = SwapWallet(
    walletRegistrationForTesting(id: 'wallet', network: BitcoinNetwork.mainnet),
    null,
    false,
  );

  Future<void> pump(WidgetTester tester, TransferState state) async {
    final bloc = _MockTransferBloc();
    when(() => bloc.state).thenReturn(state);
    when(() => bloc.stream).thenAnswer((_) => const Stream.empty());
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.themeData(AppThemeType.light),
        locale: const Locale('en'),
        localizationsDelegates: BullUiLocalizations.localizationsDelegates,
        home: Scaffold(
          body: BlocProvider<TransferBloc>.value(
            value: bloc,
            child: const SwapBalanceRow(),
          ),
        ),
      ),
    );
  }

  testWidgets('an unknown balance reads as loading while wallets load', (
    tester,
  ) async {
    await pump(tester, TransferState(fromWallet: noBalance, isStarting: true));
    expect(find.text('…'), findsOneWidget);
    expect(find.text(swapCopy('en').walletLoadFailed), findsNothing);
  });

  testWidgets('a balance still missing after loading says it failed', (
    tester,
  ) async {
    await pump(tester, TransferState(fromWallet: noBalance));
    expect(find.text('…'), findsNothing);
    expect(find.text(swapCopy('en').walletLoadFailed), findsOneWidget);
  });
}
