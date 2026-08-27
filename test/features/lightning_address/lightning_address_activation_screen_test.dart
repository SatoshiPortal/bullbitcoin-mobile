import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/features/lightning_address/domain/lightning_address_registration.dart';
import 'package:bb_mobile/features/lightning_address/presentation/lightning_address_activation_cubit.dart';
import 'package:bb_mobile/features/lightning_address/presentation/lightning_address_activation_state.dart';
import 'package:bb_mobile/features/lightning_address/ui/screens/lightning_address_activation_screen.dart';
import 'package:bb_mobile/generated/l10n/localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('old servers fail closed without exposing a claim form', (
    tester,
  ) async {
    await _pump(
      tester,
      const LightningAddressActivationState(
        status: LightningAddressActivationStatus.unsupported,
      ),
    );

    expect(find.text('Permanent names unavailable'), findsOneWidget);
    expect(find.byType(TextFormField), findsNothing);
    expect(
      find.byKey(const Key('lightning_address_online_switch')),
      findsNothing,
    );
  });

  testWidgets('an active registration shows the authoritative address', (
    tester,
  ) async {
    await _pump(tester, _activeState);

    expect(find.text('alice@pay2.bull-wallet.com'), findsOneWidget);
    expect(find.text('Lightning address is active'), findsOneWidget);
    expect(find.text('Advanced settings'), findsOneWidget);
    expect(find.byType(TextFormField), findsNothing);
  });

  testWidgets('a missing authoritative address stays explicit and retryable', (
    tester,
  ) async {
    final cubit = await _pump(
      tester,
      const LightningAddressActivationState(
        status: LightningAddressActivationStatus.addressUnavailable,
        nym: 'alice',
        permanentNamesSupported: true,
        hasPermanentNym: true,
      ),
    );

    expect(
      find.text('The server did not return your Lightning Address. Try again.'),
      findsOneWidget,
    );
    await tester.tap(find.text('Try again'));
    await tester.pump();
    expect(cubit.loadCalls, 2);
  });

  testWidgets('an unanswered claim retries the claim instead of guessing', (
    tester,
  ) async {
    final cubit = await _pump(
      tester,
      const LightningAddressActivationState(
        status: LightningAddressActivationStatus.failure,
        failure: LightningAddressActivationFailure.noServerResponse,
        nym: 'alice',
        permanentNamesSupported: true,
      ),
    );

    expect(find.text('The server did not respond'), findsOneWidget);
    await tester.tap(
      find.byKey(const Key('lightning_address_server_outcome_action')),
    );
    await tester.pump();
    expect(cubit.submitCalls, 1);
    expect(cubit.loadCalls, 1);
  });
}

const _activeState = LightningAddressActivationState(
  status: LightningAddressActivationStatus.active,
  nym: 'alice',
  registeredAddress: 'alice@pay2.bull-wallet.com',
  permanentNamesSupported: true,
  hasPermanentNym: true,
  permanentNameQuota: LightningAddressPermanentNameQuota(
    used: 1,
    cap: 1,
    remaining: 0,
  ),
);

Future<_StubCubit> _pump(
  WidgetTester tester,
  LightningAddressActivationState state,
) async {
  final cubit = _StubCubit(state);
  addTearDown(cubit.close);
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.themeData(AppThemeType.light),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('en'),
      home: BlocProvider<LightningAddressActivationCubit>.value(
        value: cubit,
        child: const LightningAddressActivationScreen(),
      ),
    ),
  );
  await tester.pump();
  return cubit;
}

class _StubCubit extends Cubit<LightningAddressActivationState>
    implements LightningAddressActivationCubit {
  _StubCubit(super.initialState);

  int loadCalls = 0;
  int submitCalls = 0;

  @override
  Future<void> load() async => loadCalls++;

  @override
  Future<void> submit() async => submitCalls++;

  @override
  void nymChanged(String value) {}

  @override
  void showRegistrationForm() {}

  @override
  LightningAddressActivationFailure? validateNym(String value) => null;

  @override
  Future<void> activateExisting() async {}

  @override
  Future<void> deactivate() async {}

  @override
  Future<void> retryWalletBehavior() async {}

  @override
  Future<void> updateWalletBehavior({
    required String walletId,
    bool? hideOnHome,
    bool? autoSweepEnabled,
  }) async {}
}
