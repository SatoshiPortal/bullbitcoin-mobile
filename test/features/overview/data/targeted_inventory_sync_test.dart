import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:overview/setup.dart';
import 'package:preferences/preferences.dart';
import 'package:primitives/primitives.dart';
import 'package:secrets/secrets.dart';
import 'package:silent/silent.dart';
import 'package:swap_feature/swap_feature.dart';
import 'package:sync/sync.dart' show SyncReason;

class _Inventory extends Mock implements WalletInventory {}

class _Environment extends Mock implements ActiveEnvironmentReader {}

class _Swaps extends Mock implements SwapActivity {}

class _Silent extends Mock implements Silent {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('missing targeted wallet never enumerates the inventory', () async {
    final inventory = _Inventory();
    final environment = _Environment();
    when(
      () => inventory.readWallet('missing'),
    ).thenAnswer((_) async => const Err(WalletRegistrationNotFoundFailure()));
    when(environment.readActiveEnvironment)
        .thenAnswer((_) async => const Ok(Environment.mainnet));
    final sync = OverviewSynchronization.open(
      inventory: inventory,
      readInSession: <T>(Future<T> Function() read) async => Ok(await read()),
      environment: environment,
      catalog: () => throw StateError('unexpected catalog read'),
      synchronize: (
        _, {
        discover = false,
        allowInitialScan = true,
        reason = SyncReason.auto,
      }) => throw StateError('unexpected synchronization'),
      refreshRevisions: () async => const Ok(null),
      swaps: () => _Swaps(),
      silent: () => _Silent(),
    );
    addTearDown(sync.close);

    await sync.coordinator.pollWallet('missing', isActive: () => true);

    verify(() => inventory.readWallet('missing')).called(1);
    verifyNoMoreInteractions(inventory);
    verifyNever(environment.readActiveEnvironment);
  });
}
