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
  testWidgets('old-server state hides every name and availability control', (
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

  testWidgets(
    'first claim shows one input and explicit permanence confirmation',
    (tester) async {
      await _pump(
        tester,
        const LightningAddressActivationState(
          status: LightningAddressActivationStatus.idle,
          permanentNamesSupported: true,
        ),
      );

      expect(find.byType(TextFormField), findsOneWidget);
      expect(find.text('Claim your permanent name'), findsOneWidget);
      expect(
        find.textContaining('cannot be renamed, cleared, or replaced'),
        findsOneWidget,
      );

      await tester.ensureVisible(find.text('Claim permanent name'));
      await tester.tap(find.text('Claim permanent name'));
      await tester.pumpAndSettle();

      expect(find.text('Claim this permanent name?'), findsOneWidget);
      expect(
        find.textContaining('This is your only Lightning Address name'),
        findsOneWidget,
      );
    },
  );

  testWidgets('claimed nym is read-only with only a product switch', (
    tester,
  ) async {
    await _pump(tester, _ownedState(online: false));

    expect(find.byType(TextFormField), findsNothing);
    expect(find.text('alice'), findsOneWidget);
    expect(
      find.text('This lifetime name is permanent and read-only.'),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('lightning_address_online_switch')),
      findsOneWidget,
    );
  });

  testWidgets('turn-off confirmation preserves Payment Page and POS explicitly', (
    tester,
  ) async {
    final cubit = await _pump(tester, _ownedState(online: true));

    await tester.ensureVisible(
      find.byKey(const Key('lightning_address_online_switch')),
    );
    await tester.tap(find.byKey(const Key('lightning_address_online_switch')));
    await tester.pumpAndSettle();

    expect(find.text('Turn off Lightning Address?'), findsOneWidget);
    expect(
      find.text(
        'Lightning payments to alice will stop until you turn the same name '
        'on again. Your Payment Page and Point of Sale stay online and payable.',
      ),
      findsOneWidget,
    );

    await tester.tap(find.text('Turn off'));
    await tester.pumpAndSettle();
    expect(cubit.deactivateCalls, 1);
  });

  testWidgets('turning on reuses the owned nym without another confirmation', (
    tester,
  ) async {
    final cubit = await _pump(tester, _ownedState(online: false));

    await tester.ensureVisible(
      find.byKey(const Key('lightning_address_online_switch')),
    );
    await tester.tap(find.byKey(const Key('lightning_address_online_switch')));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsNothing);
    expect(cubit.activateExistingCalls, 1);
  });
}

LightningAddressActivationState _ownedState({required bool online}) {
  return LightningAddressActivationState(
    status: online
        ? LightningAddressActivationStatus.active
        : LightningAddressActivationStatus.inactive,
    nym: 'alice',
    registeredAddress: online ? 'alice@pay2.bull-wallet.com' : null,
    permanentNamesSupported: true,
    hasPermanentNym: true,
    permanentNameQuota: const LightningAddressPermanentNameQuota(
      used: 1,
      cap: 1,
      remaining: 0,
    ),
  );
}

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

  int activateExistingCalls = 0;
  int deactivateCalls = 0;

  @override
  Future<void> load() async {}

  @override
  void nymChanged(String value) {}

  @override
  void showRegistrationForm() {}

  @override
  LightningAddressActivationFailure? validateNym(String value) => null;

  @override
  Future<void> submit() async {}

  @override
  Future<void> activateExisting() async {
    activateExistingCalls += 1;
  }

  @override
  Future<void> deactivate() async {
    deactivateCalls += 1;
  }

  @override
  Future<void> updateWalletBehavior({
    required String walletId,
    bool? hideOnHome,
    bool? autoSweepEnabled,
  }) async {}
}
