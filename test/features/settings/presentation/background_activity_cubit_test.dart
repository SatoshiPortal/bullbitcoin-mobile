import 'package:background_tasks/background_tasks.dart';
import 'package:bb_mobile/features/settings/domain/usecases/get_background_activity_usecase.dart';
import 'package:bb_mobile/features/settings/domain/usecases/open_background_activity_settings_usecase.dart';
import 'package:bb_mobile/features/settings/presentation/bloc/background_activity_cubit.dart';
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

BackgroundActivityCubit _cubit(_Gateway gateway) => BackgroundActivityCubit(
  getBackgroundActivityUsecase: GetBackgroundActivityUsecase(gateway: gateway),
  openBackgroundActivitySettingsUsecase: OpenBackgroundActivitySettingsUsecase(
    gateway: gateway,
  ),
);

void main() {
  test('reports the battery restriction as the OS sees it', () async {
    final gateway = _Gateway();
    final cubit = _cubit(gateway);
    addTearDown(cubit.close);

    await cubit.refresh();
    expect(cubit.state, BackgroundActivityStatus.notApplicable);

    gateway.unrestricted = false;
    await cubit.refresh();
    expect(cubit.state, BackgroundActivityStatus.restricted);

    gateway.unrestricted = true;
    await cubit.refresh();
    expect(cubit.state, BackgroundActivityStatus.unrestricted);
  });

  test('opens the app settings for the battery choice', () async {
    final gateway = _Gateway();
    final cubit = _cubit(gateway);
    addTearDown(cubit.close);

    await cubit.openSettings();

    expect(gateway.opened, 1);
  });
}
