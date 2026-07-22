import 'package:bb_mobile/core/seed/domain/usecases/get_default_seed_usecase.dart';
import 'package:bb_mobile/core/settings/data/settings_repository.dart';
import 'package:bb_mobile/features/sp/domain/entities/sp_coin.dart';
import 'package:bb_mobile/features/sp/domain/entities/sp_notification.dart';
import 'package:bb_mobile/features/sp/domain/repositories/sp_account_repository.dart';
import 'package:bb_mobile/features/sp/domain/repositories/sp_backend_config_repository.dart';
import 'package:bb_mobile/features/sp/presentation/sp_cubit.dart';
import 'package:bb_mobile/features/sp/sp_locator.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:mocktail/mocktail.dart';

import 'sp_fakes.dart';

// Real-wiring SP no-autoscan invariant. Unlike the cubit-only cubit_scan_test,
// this boots the SpCubit through the actual `sp_locator` graph (LoadSpWalletData
// -> EnsureSpSession -> the account repository port) with ONLY the outbound
// repository port faked. FakeSpAccountRepository counts every scanOnce reaching
// the Rust boundary, so an accidental auto-scan anywhere in that chain trips the
// counter. We then let a REAL duration elapse (not a single microtask) so any
// stray timer/lifecycle-driven scan would have fired.

class _MockSettingsRepository extends Mock implements SettingsRepository {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late GetIt locator;
  late FakeSpAccountRepository fakeRepo;
  late SpCubit cubit;

  setUp(() {
    fakeRepo = FakeSpAccountRepository();
    locator = GetIt.asNewInstance();
    locator.allowReassignment = true;

    // External collaborators SpLocator's use cases resolve. The seed is never
    // read on this path (the fake reports a live session, so EnsureSpSession
    // returns the snapshot without reconstructing), but the graph resolves it.
    locator.registerSingleton<GetDefaultSeedUsecase>(
      MockGetDefaultSeedUsecase(),
    );
    locator.registerSingleton<SettingsRepository>(_MockSettingsRepository());

    // Real SP wiring: registers the whole use case + presentation graph.
    SpLocator.setup(locator);

    // Swap ONLY the outbound ports for in-memory fakes. The lazy singletons are
    // not yet resolved, so the real BwkSpAccountRepository is never constructed.
    locator.registerSingleton<SpAccountRepository>(fakeRepo);
    locator.registerSingleton<SpBackendConfigRepository>(
      FakeSpBackendConfigRepository(),
    );

    cubit = locator<SpCubit>();
  });

  tearDown(() async {
    await cubit.close();
    await fakeRepo.disposeStreams();
    await locator.reset();
  });

  // A real elapse, long enough that any stray timer- or lifecycle-driven scan
  // would have fired.
  Future<void> settle() =>
      Future<void>.delayed(const Duration(milliseconds: 200));

  group('SP no-autoscan invariant (real sp_locator wiring)', () {
    test('load() through the real graph never reaches scanOnce', () async {
      expect(fakeRepo.scanOnceCount, 0);

      await cubit.load();
      await settle();

      expect(fakeRepo.scanOnceCount, 0);
    });

    test('inbound notifications (electrum tx / new output / scan completed) '
        'never trigger a scan', () async {
      await cubit.load();

      fakeRepo.emitNotification(
        SpElectrumTx(
          kind: SpCoinSource.segwit,
          txid: 'aabbcc',
          amountSat: BigInt.from(1000),
        ),
      );
      fakeRepo.emitNotification(SpNewOutput('abc:0', BigInt.zero));
      fakeRepo.emitNotification(const SpScanCompleted());
      await settle();

      expect(fakeRepo.scanOnceCount, 0);
    });

    test(
      'only an explicit user scan() reaches scanOnce, exactly once',
      () async {
        await cubit.load();
        await settle();
        expect(fakeRepo.scanOnceCount, 0);

        await cubit.scan();

        expect(fakeRepo.scanOnceCount, 1);
      },
    );
  });
}
