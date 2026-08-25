import 'package:bb_mobile/core/electrum/domain/value_objects/electrum_server_status.dart';
import 'package:bb_mobile/features/electrum_settings/interface_adapters/presenters/bloc/electrum_settings_bloc.dart';
import 'package:bb_mobile/features/electrum_settings/interface_adapters/presenters/view_models/electrum_server_view_model.dart';
import 'package:flutter_test/flutter_test.dart';

ElectrumServerViewModel _server(String url, ElectrumServerStatus status) =>
    ElectrumServerViewModel(url: url, status: status, priority: 0);

void main() {
  test('clearnet failures do not report an onion route failure', () {
    final state = ElectrumSettingsState(
      defaultServers: [
        _server(
          'ssl://electrum.example.com:50002',
          ElectrumServerStatus.offline,
        ),
      ],
    );

    expect(state.activeOnionServersAreOffline, isFalse);
  });

  test('offline custom onion servers report an onion route failure', () {
    final state = ElectrumSettingsState(
      defaultServers: [
        _server(
          'ssl://electrum.example.com:50002',
          ElectrumServerStatus.online,
        ),
      ],
      customServers: [
        _server('ssl://hidden.onion:50002', ElectrumServerStatus.offline),
      ],
    );

    expect(state.activeOnionServersAreOffline, isTrue);
  });

  test('an online onion server does not report an onion route failure', () {
    final state = ElectrumSettingsState(
      customServers: [
        _server('ssl://hidden.onion:50002', ElectrumServerStatus.online),
      ],
    );

    expect(state.activeOnionServersAreOffline, isFalse);
  });
}
