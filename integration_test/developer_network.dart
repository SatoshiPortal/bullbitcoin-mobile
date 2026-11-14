import 'package:bb_mobile/core/settings/domain/repositories/settings_repository.dart';
import 'package:primitives/primitives.dart' show Ok;
import 'package:bb_mobile/features/settings/domain/settings_entity.dart';
import 'package:bb_mobile/features/settings/domain/settings_failure.dart';
import 'package:bb_mobile/features/settings/domain/usecases/set_environment_usecase.dart';
import 'package:bb_mobile/features/settings/domain/usecases/set_is_dev_mode_usecase.dart';
import 'package:bb_mobile/features/settings/domain/usecases/set_is_superuser_usecase.dart';
import 'package:bb_mobile/locator.dart';
import 'package:flutter_test/flutter_test.dart';

final _ok = isA<Ok<void, SettingsFailure>>();

/// Selects a test network the way a user can: test networks are a developer
/// feature, refused unless superuser and developer mode are both on
/// (`SetActiveNetworkUsecase`). Each write is asserted, so a refused setup
/// fails here rather than as a confusing failure further down.
///
/// Call it from `setUpAll`. The restore is registered before the first write,
/// so it also runs when the setup fails halfway, and it runs when the group
/// ends: back to mainnet, then both flags as they were (mainnet first, since
/// turning developer mode off also leaves test networks). Every restore step
/// is attempted before any is asserted, so one failure cannot skip the others
/// and leak developer mode into the groups that follow in the same run.
Future<void> selectDeveloperNetwork(Environment environment) async {
  final previous = await locator<SettingsRepository>().fetch();
  addTearDown(() async {
    final restored = [
      await locator<SetEnvironmentUsecase>().execute(Environment.mainnet),
      await locator<SetIsDevModeUsecase>().execute(
        previous.isDevModeEnabled ?? false,
      ),
      await locator<SetIsSuperuserUsecase>().execute(
        previous.isSuperuser ?? false,
      ),
    ];
    expect(restored, everyElement(_ok));
  });
  expect(await locator<SetIsSuperuserUsecase>().execute(true), _ok);
  expect(await locator<SetIsDevModeUsecase>().execute(true), _ok);
  expect(await locator<SetEnvironmentUsecase>().execute(environment), _ok);
}
