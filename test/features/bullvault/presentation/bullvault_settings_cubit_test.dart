import 'dart:async';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/bullvault/domain/bullvault_failure.dart';
import 'package:bb_mobile/features/bullvault/domain/entities/bullvault_inspection.dart';
import 'package:bb_mobile/features/bullvault/domain/entities/bullvault_record.dart';
import 'package:bb_mobile/features/bullvault/domain/usecases/inspect_bullvault_usecase.dart';
import 'package:bb_mobile/features/bullvault/domain/usecases/load_bullvault_menu_usecase.dart';
import 'package:bb_mobile/features/bullvault/presentation/bullvault_settings_cubit.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import '../bullvault_test_fixture.dart';

class _Menu extends Mock implements LoadBullVaultMenuUsecase {}

class _Inspect extends Mock implements InspectBullVaultUsecase {}

void main() {
  test(
    'menu errors stay visible and can be retried into an empty menu',
    () async {
      final menu = _Menu();
      when(
        menu.execute,
      ).thenAnswer((_) async => const Err(BullVaultBackupStatusFailure()));
      final cubit = BullVaultSettingsCubit(menu, _Inspect());
      await cubit.load();
      expect(cubit.state, isA<BullVaultSettingsFailed>());
      when(menu.execute).thenAnswer((_) async => const Ok([]));
      await cubit.load();
      expect((cubit.state as BullVaultMenuLoaded).records, isEmpty);
      verify(menu.execute).called(2);
      await cubit.close();
    },
  );
  test('a slow old selection cannot replace a newly selected vault', () async {
    final inspect = _Inspect();
    final old = Completer<Result<BullVaultInspection, BullVaultFailure>>();
    final selected = testBullVaultCreateResult(walletId: 'selected');
    final previous = testBullVaultCreateResult(walletId: 'previous');
    when(() => inspect.execute('previous')).thenAnswer((_) => old.future);
    when(() => inspect.execute('selected')).thenAnswer(
      (_) async =>
          Ok(BullVaultInspection(selected.record, selected.wallet, const {})),
    );
    final cubit = BullVaultSettingsCubit(_Menu(), inspect);
    final stale = cubit.load('previous');
    await cubit.load('selected');
    old.complete(
      Ok(BullVaultInspection(previous.record, previous.wallet, const {})),
    );
    await stale;
    expect(
      (cubit.state as BullVaultInspectionLoaded).inspection.record.walletId,
      'selected',
    );
    await cubit.close();
  });
  test('closing a menu ignores late reads', () async {
    final menu = _Menu();
    final delayed =
        Completer<Result<List<BullVaultRecord>, BullVaultFailure>>();
    when(menu.execute).thenAnswer((_) => delayed.future);
    final cubit = BullVaultSettingsCubit(menu, _Inspect());
    final loading = cubit.load();
    await cubit.close();
    delayed.complete(const Ok([]));
    await loading;
    expect(cubit.state, isA<BullVaultSettingsLoading>());
  });
}
