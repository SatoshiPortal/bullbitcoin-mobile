import 'package:preferences/preferences.dart';
import 'package:primitives/primitives.dart' show Ok;
import 'package:settings/settings.dart';
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
  final settings = locator<Settings>();
  final previous = (await locator<Preferences>().fetch()).fold(
    (value) => value,
    (failure) => throw StateError('Preferences unavailable'),
  );
  addTearDown(() async {
    final restored = [
      await settings.setStartupEnvironment(Environment.mainnet),
      await settings.setStartupDevMode(previous.isDevModeEnabled ?? false),
      await settings.setStartupSuperuser(previous.isSuperuser ?? false),
    ];
    expect(restored, everyElement(_ok));
  });
  expect(await settings.setStartupSuperuser(true), _ok);
  expect(await settings.setStartupDevMode(true), _ok);
  expect(await settings.setStartupEnvironment(environment), _ok);
}
