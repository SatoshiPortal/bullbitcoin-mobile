import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/features/lightning_address/domain/lightning_address_registration.dart';
import 'package:bb_mobile/features/lightning_address/presentation/lightning_address_activation_cubit.dart';
import 'package:bb_mobile/features/lightning_address/presentation/lightning_address_activation_state.dart';
import 'package:bb_mobile/features/lightning_address/ui/screens/lightning_address_activation_screen.dart';
import 'package:bb_mobile/generated/l10n/localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_flutter/qr_flutter.dart';

void main() {
  String? copiedText;

  setUp(() {
    copiedText = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          if (call.method == 'Clipboard.setData') {
            copiedText =
                (call.arguments as Map<Object?, Object?>)['text'] as String?;
          }
          return null;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

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

  testWidgets('first claim shows one input and the permanence explanation', (
    tester,
  ) async {
    await _pump(
      tester,
      const LightningAddressActivationState(
        status: LightningAddressActivationStatus.idle,
        permanentNamesSupported: true,
      ),
    );

    expect(find.byType(TextFormField), findsOneWidget);
    expect(find.text('Claim your nym'), findsNWidgets(2));
    expect(
      find.text(
        'A pseudonym tied to your BULL wallet. It allows anyone to send you '
        'Bitcoin payments anonymously just by typing your nym in their wallet, '
        'and you will receive it in your instant payments wallet. Choose wisely: '
        "you can't change it without creating an entirely new Bitcoin wallet.",
      ),
      findsOneWidget,
    );

    await tester.ensureVisible(find.text('Claim your nym').last);
    await tester.tap(find.text('Claim your nym').last);
    await tester.pumpAndSettle();

    expect(find.text('Claim this permanent name?'), findsNothing);
  });

  testWidgets('active nym shows its address and hides secondary metadata', (
    tester,
  ) async {
    await _pump(tester, _ownedState(online: true));

    expect(find.byType(TextFormField), findsNothing);
    expect(find.text('Lightning address is active'), findsOneWidget);
    expect(find.text('alice@pay2.bull-wallet.com'), findsOneWidget);
    expect(find.text('Name'), findsNothing);
    expect(
      find.text('This lifetime name is permanent and read-only.'),
      findsNothing,
    );
    expect(find.text('Advanced settings'), findsOneWidget);
    expect(
      find.byKey(const Key('lightning_address_online_switch')),
      findsNothing,
    );
  });

  testWidgets('inactive nym retains the same server-owned address', (
    tester,
  ) async {
    await _pump(tester, _ownedState(online: false));

    expect(find.text('Lightning Address is inactive'), findsOneWidget);
    expect(find.text('alice@pay2.bull-wallet.com'), findsOneWidget);
    expect(find.text('Name'), findsNothing);
    expect(find.text('Advanced settings'), findsOneWidget);
  });

  testWidgets(
    'address tap opens QR and copy actions without explorer actions',
    (tester) async {
      await _pump(tester, _ownedState(online: true));

      await tester.tap(find.byKey(const Key('lightning_address_tile')));
      await tester.pumpAndSettle();

      expect(find.byType(QrImageView), findsOneWidget);
      expect(find.text('Tap to copy'), findsOneWidget);
      expect(find.text('Copy Link'), findsNothing);
      expect(find.text('View in Explorer'), findsNothing);

      await tester.tap(find.text('Tap to copy'));
      await tester.pumpAndSettle();
      expect(copiedText, 'alice@pay2.bull-wallet.com');
      await tester.pump(const Duration(seconds: 4));
    },
  );

  testWidgets('long press copies the Lightning Address', (tester) async {
    await _pump(tester, _ownedState(online: true));

    await tester.longPress(find.byKey(const Key('lightning_address_tile')));
    await tester.pump();

    expect(copiedText, 'alice@pay2.bull-wallet.com');
    await tester.pump(const Duration(seconds: 4));
  });

  testWidgets('missing lookup address is explicit and reloadable', (
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
    expect(find.text('Lightning address is active'), findsNothing);
    await tester.tap(find.text('Try again'));
    await tester.pump();
    expect(cubit.loadCalls, 2);
  });

  testWidgets('turning off uses the same direct progress flow as turning on', (
    tester,
  ) async {
    final cubit = await _pump(tester, _ownedState(online: true));

    await tester.tap(find.text('Advanced settings'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.byKey(const Key('lightning_address_online_switch')),
    );
    await tester.tap(find.byKey(const Key('lightning_address_online_switch')));
    await tester.pumpAndSettle();

    expect(cubit.deactivateCalls, 1);
    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets('turning on reuses the owned nym without another confirmation', (
    tester,
  ) async {
    final cubit = await _pump(tester, _ownedState(online: false));

    await tester.tap(find.text('Advanced settings'));
    await tester.pumpAndSettle();
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
    registeredAddress: 'alice@pay2.bull-wallet.com',
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
  int loadCalls = 0;

  @override
  Future<void> load() async {
    loadCalls += 1;
  }

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
