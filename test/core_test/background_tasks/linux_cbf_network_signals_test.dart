import 'dart:async';

import 'package:bb_mobile/core/background_tasks/linux_cbf_network_signals.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nm/nm.dart';

class _Client extends Mock implements NetworkManagerClient {}

void main() {
  test(
    'Linux distinguishes a metered default route from free and unknown cost',
    () {
      ({bool available, bool? metered}) read(NetworkManagerMetered cost) =>
          mapLinuxCbfNetworkSignal(
            state: NetworkManagerState.connectedGlobal,
            connectivity: NetworkManagerConnectivityState.full,
            metered: cost,
          );
      expect(read(NetworkManagerMetered.yes), (available: true, metered: true));
      expect(read(NetworkManagerMetered.no), (available: true, metered: false));
      expect(read(NetworkManagerMetered.unknown), (
        available: true,
        metered: null,
      ));
    },
  );

  test(
    'a captive portal is offline while disabled validation keeps a global route usable',
    () {
      expect(
        mapLinuxCbfNetworkSignal(
          state: NetworkManagerState.connectedGlobal,
          connectivity: NetworkManagerConnectivityState.portal,
          metered: NetworkManagerMetered.no,
        ).available,
        isFalse,
      );
      expect(
        mapLinuxCbfNetworkSignal(
          state: NetworkManagerState.connectedGlobal,
          connectivity: NetworkManagerConnectivityState.unknown,
          metered: NetworkManagerMetered.unknown,
        ).available,
        isTrue,
      );
    },
  );

  test(
    'Linux reads cached properties, observes cost changes and releases D-Bus',
    () async {
      final client = _Client();
      final changes = StreamController<List<String>>();
      var cost = NetworkManagerMetered.no;
      when(() => client.connect()).thenAnswer((_) async {});
      when(() => client.close()).thenAnswer((_) async {});
      when(() => client.version).thenReturn('1.48');
      when(() => client.state).thenReturn(NetworkManagerState.connectedGlobal);
      when(
        () => client.connectivity,
      ).thenReturn(NetworkManagerConnectivityState.full);
      when(() => client.metered).thenAnswer((_) => cost);
      when(() => client.propertiesChanged).thenAnswer((_) => changes.stream);
      final source = LinuxCbfNetworkSignals(createClient: () => client);
      expect((await source.read())?.metered, isFalse);
      expect((await source.read())?.metered, isFalse);
      final updated = source.changes.first;
      cost = NetworkManagerMetered.yes;
      changes.add(['Metered']);
      expect((await updated).metered, isTrue);
      await source.dispose();
      await changes.close();
      verify(() => client.connect()).called(1);
      verify(() => client.close()).called(1);
    },
  );
}
