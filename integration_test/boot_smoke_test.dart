import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';
import 'package:bb_mobile/features/bullnym/public/bullnym_facade.dart';
import 'package:bb_mobile/features/deterministic_wallets/public/deterministic_wallets_facade.dart';
import 'package:bb_mobile/features/keychain_manifest/public/keychain_manifest_facade.dart';
import 'package:bb_mobile/features/nostr_identity/public/nostr_identity_facade.dart';
import 'package:bb_mobile/features/send/domain/ports/liquid_direct_pay_port.dart';
import 'package:bb_mobile/features/send/domain/usecases/build_bullpay_proof_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/try_liquid_direct_pay_usecase.dart';
import 'package:bb_mobile/features/bip85_entropy/router.dart';
import 'package:bb_mobile/features/settings/presentation/bloc/settings_cubit.dart';
import 'package:bb_mobile/features/wallet/ui/wallet_router.dart';
import 'package:bb_mobile/locator.dart';
import 'package:bb_mobile/main.dart';
import 'package:bb_mobile/router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:integration_test/integration_test.dart';

// SPEC-BOOT-01 — the wiring smoke that would have caught the duplicate
// NostrIdentityLocator.setup boot crash (R2-1/AD-10). Runs the REAL DI graph via
// Bull.init() on the Linux desktop device: registration is invisible to
// `analyze` and unit tests, and the crash only surfaces when a consumer resolves
// the ambiguous NostrIdentityFacade during eager setup - so only launching the
// real graph proves it. This file must be the non-negotiable cascade gate from
// pr12 upward.
Future<void> main({bool isInitialized = false}) async {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  if (!isInitialized) await Bull.init();

  test('Bull.init builds the real DI graph without a duplicate registration', () {
    // Resolving NostrIdentityFacade is the crux: the pr12 duplicate
    // NostrIdentityLocator.setup made this type ambiguous, so this throws at the
    // first resolution (which eager KeychainManifest/Bullnym/LightningAddress
    // setup performs) on the real graph. A single registration resolves cleanly.
    expect(() => locator<NostrIdentityFacade>(), returnsNormally);
    expect(() => locator<KeychainManifestFacade>(), returnsNormally);
    expect(() => locator<BullnymFacade>(), returnsNormally);
    expect(() => locator<DeterministicWalletsFacade>(), returnsNormally);
    expect(() => locator<WalletRepository>(), returnsNormally);
    expect(() => locator<SettingsCubit>(), returnsNormally);
    // PR25 wiring (SPEC-BOOT-01+): the LUD-22 direct-pay port + usecases
    // resolve once from the real graph (the SendCubit consumes them).
    expect(() => locator<LiquidDirectPayPort>(), returnsNormally);
    expect(() => locator<BuildBullpayProofUsecase>(), returnsNormally);
    expect(() => locator<TryLiquidDirectPayUsecase>(), returnsNormally);
  });

  test('the app router graph constructs against the booted locator', () {
    // Router construction resolves route-wired dependencies from the real
    // locator; constructing it is the DI analogue of the boot smoke. (Pumping
    // the full BullBitcoinWalletApp is intentionally NOT done here: its live
    // startup blocs/timers make an integration pump non-deterministic - the
    // boot crash itself is proven by Bull.init succeeding above, which is the
    // exact startup path initLocator runs on.)
    expect(() => AppRouter.router, returnsNormally);
  });

  testWidgets('the /bip85-home dev route is guarded against a deep link', (
    tester,
  ) async {
    // Exercise the REAL R2-KI2 route guard (Bip85EntropyRouter.route, which
    // reads locator<SettingsCubit>() populated by Bull.init) against a minimal
    // router - no live WalletBloc timers, so the frame settles. A fresh install
    // is not superuser+dev, so a deep link to /bip85-home must redirect to the
    // wallet home instead of exposing the raw-entropy dev screen.
    final router = GoRouter(
      initialLocation: WalletRoute.walletHome.path,
      routes: [
        GoRoute(
          path: WalletRoute.walletHome.path,
          builder: (context, state) => const SizedBox.shrink(),
        ),
        Bip85EntropyRouter.route,
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pump();

    router.go(Bip85EntropyRoute.bip85Home.path);
    await tester.pump();

    expect(
      router.routerDelegate.currentConfiguration.uri.toString(),
      WalletRoute.walletHome.path,
    );
  });
}
