import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/check_wallet_status_usecase.dart';
import 'package:bb_mobile/core/widgets/mnemonic_widget.dart';
import 'package:bb_mobile/features/import_mnemonic/domain/check_duplicate_mnemonic_usecase.dart';
import 'package:bb_mobile/features/import_mnemonic/domain/import_wallet_usecase.dart';
import 'package:bb_mobile/features/import_mnemonic/presentation/cubit.dart';
import 'package:bb_mobile/features/import_mnemonic/ui/mnemonic_page.dart';
import 'package:bb_mobile/generated/l10n/localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:screen_privacy/screen_privacy.dart';

/// The channel through which `no_screenshot` sets the OS capture flag.
const _channel = MethodChannel('com.flutterplaza.no_screenshot_methods');

const _warning =
    'Screen capture protection could not be enabled. Screenshots and screen '
    'recordings of this screen may not be blocked.';

class _MockImportWallet extends Mock implements ImportWalletUsecase {}

class _MockCheckWalletStatus extends Mock implements CheckWalletStatusUsecase {}

class _MockCheckDuplicate extends Mock
    implements CheckDuplicateMnemonicUsecase {}

/// Makes the platform answer [verdict] to every request to block capture.
void _platformBlocksCapture({required bool verdict}) {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
        _channel,
        (call) async => call.method == 'screenshotOff' ? verdict : true,
      );
  addTearDown(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, null),
  );
}

Future<void> _pumpPage(WidgetTester tester) async {
  final cubit = ImportMnemonicCubit(
    importWalletUsecase: _MockImportWallet(),
    checkWalletUsecase: _MockCheckWalletStatus(),
    checkDuplicateMnemonicUsecase: _MockCheckDuplicate(),
  );
  addTearDown(cubit.close);

  await tester.pumpWidget(
    BlocProvider<ImportMnemonicCubit>.value(
      value: cubit,
      child: MaterialApp(
        theme: AppTheme.themeData(AppThemeType.light),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const MnemonicPage(),
      ),
    ),
  );
  // Long enough for every automatic retry.
  await tester.pump(const Duration(seconds: 2));
}

void main() {
  setUp(() {
    // The controller is process-wide: start from the user's default.
    ScreenCaptureProtection.instance.enabledByUser = true;
  });

  testWidgets('the phrase field waits behind a warning while the platform '
      'refuses to block capture', (tester) async {
    _platformBlocksCapture(verdict: false);

    await _pumpPage(tester);

    expect(find.byType(MnemonicWidget), findsNothing);
    expect(find.text(_warning), findsOneWidget);
  });

  testWidgets('Continue anyway shows the phrase field without protection', (
    tester,
  ) async {
    _platformBlocksCapture(verdict: false);
    await _pumpPage(tester);

    await tester.tap(find.text('Continue anyway'));
    await tester.pump();

    expect(find.byType(MnemonicWidget), findsOneWidget);
  });

  testWidgets('the phrase field shows at once when capture is blocked', (
    tester,
  ) async {
    _platformBlocksCapture(verdict: true);

    await _pumpPage(tester);

    expect(find.byType(MnemonicWidget), findsOneWidget);
    expect(find.text(_warning), findsNothing);
  });

  testWidgets('the phrase field shows at once when the user turned '
      'protection off', (tester) async {
    _platformBlocksCapture(verdict: false);
    ScreenCaptureProtection.instance.enabledByUser = false;
    addTearDown(() => ScreenCaptureProtection.instance.enabledByUser = true);

    await _pumpPage(tester);

    expect(find.byType(MnemonicWidget), findsOneWidget);
    expect(find.text(_warning), findsNothing);
  });
}
