import 'package:background_tasks/background_tasks.dart';
import 'package:bb_mobile/features/wizard/domain/usecase/open_battery_settings_usecase.dart';
import 'package:bb_mobile/features/wizard/domain/usecase/read_background_activity_usecase.dart';
import 'package:bb_mobile/features/wizard/presentation/background_activity_cubit.dart';
import 'package:flutter_test/flutter_test.dart';

class _Gateway implements BackgroundActivityGateway {
  bool? unrestricted;
  int opened = 0;

  @override
  Future<bool?> isUnrestricted() async => unrestricted;

  @override
  Future<bool> openSettings() async {
    opened++;
    return true;
  }
}

void main() {
  test('the notice shows only while Android restricts the app', () async {
    final gateway = _Gateway();
    final cubit = BackgroundActivityCubit(
      read: ReadBackgroundActivityUsecase(gateway: gateway),
      open: OpenBatterySettingsUsecase(gateway: gateway),
    );
    addTearDown(cubit.close);

    await cubit.refresh();
    expect(cubit.state, isFalse, reason: 'not applicable');
    gateway.unrestricted = false;
    await cubit.refresh();
    expect(cubit.state, isTrue);
    await cubit.openSettings();
    expect(gateway.opened, 1);
    gateway.unrestricted = true;
    await cubit.refresh();
    expect(cubit.state, isFalse);
  });
}
