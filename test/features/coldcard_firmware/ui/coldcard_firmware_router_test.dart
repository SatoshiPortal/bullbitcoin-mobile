import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/coldcard_firmware/domain/coldcard_firmware_failure.dart';
import 'package:bb_mobile/features/coldcard_firmware/domain/usecases/cancel_coldcard_firmware_download_usecase.dart';
import 'package:bb_mobile/features/coldcard_firmware/domain/usecases/download_and_verify_coldcard_firmware_usecase.dart';
import 'package:bb_mobile/features/coldcard_firmware/domain/usecases/get_latest_coldcard_firmware_usecase.dart';
import 'package:bb_mobile/features/coldcard_firmware/domain/usecases/save_coldcard_firmware_usecase.dart';
import 'package:bb_mobile/features/coldcard_firmware/presentation/cubit/coldcard_firmware_cubit.dart';
import 'package:bb_mobile/features/coldcard_firmware/ui/coldcard_firmware_router.dart';
import 'package:bb_mobile/features/coldcard_firmware/ui/screens/coldcard_model_select_screen.dart';
import 'package:bb_mobile/features/coldcard_firmware/ui/screens/coldcard_update_screen.dart';
import 'package:bb_mobile/generated/l10n/localization.dart';
import 'package:bb_mobile/locator.dart';
import 'package:coldcard_firmware/coldcard_firmware.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

class _MockGetLatestUsecase extends Mock
    implements GetLatestColdcardFirmwareUsecase {}

class _MockDownloadAndVerifyUsecase extends Mock
    implements DownloadAndVerifyColdcardFirmwareUsecase {}

class _MockSaveUsecase extends Mock implements SaveColdcardFirmwareUsecase {}

class _MockCancelDownloadUsecase extends Mock
    implements CancelColdcardFirmwareDownloadUsecase {}

void main() {
  setUp(() async {
    await locator.reset();
  });

  tearDown(() async {
    await locator.reset();
  });

  Future<void> pumpDeviceRoute(
    WidgetTester tester, {
    required Object? extra,
  }) async {
    final router = GoRouter(
      initialLocation: ColdcardFirmwareRoute.coldcardUpdate.path,
      routes: ColdcardFirmwareRouter.routes,
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      MaterialApp.router(
        routerConfig: router,
        theme: AppTheme.themeData(AppThemeType.light),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
      ),
    );

    router.go(ColdcardFirmwareRoute.coldcardUpdateDevice.path, extra: extra);
    await tester.pumpAndSettle();
  }

  void registerFailingCubitFactory({required void Function() onConstruct}) {
    locator.registerFactory<ColdcardFirmwareCubit>(() {
      onConstruct();
      throw StateError('The redirect must run before Cubit construction.');
    });
  }

  testWidgets('null extra redirects without constructing a Cubit', (
    tester,
  ) async {
    var cubitConstructions = 0;
    registerFailingCubitFactory(onConstruct: () => cubitConstructions++);

    await pumpDeviceRoute(tester, extra: null);

    expect(find.byType(ColdcardModelSelectScreen), findsOneWidget);
    expect(find.byType(ColdcardUpdateScreen), findsNothing);
    expect(cubitConstructions, 0);
  });

  testWidgets('wrong-type extra redirects without constructing a Cubit', (
    tester,
  ) async {
    var cubitConstructions = 0;
    registerFailingCubitFactory(onConstruct: () => cubitConstructions++);

    await pumpDeviceRoute(tester, extra: 'Coldcard Q');

    expect(find.byType(ColdcardModelSelectScreen), findsOneWidget);
    expect(find.byType(ColdcardUpdateScreen), findsNothing);
    expect(cubitConstructions, 0);
  });

  testWidgets('ColdcardModel extra opens the update flow and loads the model', (
    tester,
  ) async {
    final getLatest = _MockGetLatestUsecase();
    final downloadAndVerify = _MockDownloadAndVerifyUsecase();
    final save = _MockSaveUsecase();
    final cancelDownload = _MockCancelDownloadUsecase();
    when(
      () => getLatest.execute(ColdcardModel.q),
    ).thenAnswer((_) async => const Err(ColdcardFirmwareNetworkFailure()));
    when(() => cancelDownload.execute()).thenReturn(null);
    var cubitConstructions = 0;
    locator.registerFactory<ColdcardFirmwareCubit>(() {
      cubitConstructions++;
      return ColdcardFirmwareCubit(
        getLatestColdcardFirmwareUsecase: getLatest,
        downloadAndVerifyColdcardFirmwareUsecase: downloadAndVerify,
        saveColdcardFirmwareUsecase: save,
        cancelColdcardFirmwareDownloadUsecase: cancelDownload,
      );
    });

    await pumpDeviceRoute(tester, extra: ColdcardModel.q);

    expect(find.byType(ColdcardUpdateScreen), findsOneWidget);
    expect(find.byType(ColdcardModelSelectScreen), findsNothing);
    expect(cubitConstructions, 1);
    verify(() => getLatest.execute(ColdcardModel.q)).called(1);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });
}
