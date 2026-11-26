import 'dart:async';

import 'package:network/network.dart';
import 'package:primitives/primitives.dart';

enum SettingsServiceHealth { checking, healthy, unhealthy }

final class WatchSettingsServiceHealthUsecase {
  final NetworkStatus _status;

  const WatchSettingsServiceHealthUsecase(this._status);

  Stream<SettingsServiceHealth> execute() =>
      Stream<SettingsServiceHealth>.multi((listener) {
        final session = _status.session();
        unawaited(session.check());
        final subscription = session.watch().listen((update) {
          listener.add(switch (update) {
            Ok(value: StatusSnapshot(isRefreshing: true)) =>
              SettingsServiceHealth.checking,
            Ok(value: StatusSnapshot(:final services)) =>
              services.allServicesOnline
                  ? SettingsServiceHealth.healthy
                  : SettingsServiceHealth.unhealthy,
            Err() => SettingsServiceHealth.unhealthy,
          });
        });
        listener.onCancel = () async {
          final stopped = session.close();
          await subscription.cancel();
          await stopped;
        };
      }).distinct();
}
