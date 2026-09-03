import 'package:bb_mobile/core/blockchain/domain/usecases/broadcast_bitcoin_transaction_usecase.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/features/broadcast_signed_tx/presentation/broadcast_signed_tx_cubit.dart';
import 'package:bb_mobile/features/broadcast_signed_tx/presentation/pages/broadcast_signed_tx_page.dart';
import 'package:bb_mobile/features/broadcast_signed_tx/type.dart';
import 'package:bb_mobile/generated/l10n/localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

class _MockBroadcast extends Mock
    implements BroadcastBitcoinTransactionUsecase {}

void main() {
  testWidgets('typing stays editable until the signer result is submitted', (
    tester,
  ) async {
    final broadcast = _MockBroadcast();
    final cubit = BroadcastSignedTxCubit(
      broadcastBitcoinTransactionUsecase: broadcast,
      request: const BroadcastSignedTxRequest(collectSignerResult: true),
    );
    addTearDown(cubit.close);
    final router = GoRouter(
      routes: [
        GoRoute(path: '/', builder: (_, _) => const Scaffold()),
        GoRoute(
          path: '/result',
          builder: (_, _) => BlocProvider.value(
            value: cubit,
            child: const BroadcastSignedTxPage(),
          ),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      MaterialApp.router(
        theme: AppTheme.themeData(AppThemeType.light),
        routerConfig: router,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
      ),
    );
    final result = router.push<String>('/result');
    await tester.pumpAndSettle();
    for (final text in ['c', '', 'cHNidP8=']) {
      await tester.enterText(find.byType(TextField), text);
      await tester.pump();
      expect(cubit.state.collectedSignerResult, isNull);
      expect(find.byType(BroadcastSignedTxPage), findsOneWidget);
    }
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(await result, 'cHNidP8=');
    verifyNever(() => broadcast.execute(any(), isPsbt: any(named: 'isPsbt')));
  });
}
