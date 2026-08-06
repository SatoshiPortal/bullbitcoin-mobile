import 'package:bb_mobile/core/status/domain/entity/service_status.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('disabled Boltz does not make the remaining services unhealthy', () {
    const online = ServiceStatusInfo(
      status: ServiceStatus.online,
      name: 'service',
    );
    const status = AllServicesStatus(
      internetConnection: online,
      bitcoinElectrum: online,
      liquidElectrum: online,
      boltz: ServiceStatusInfo(
        status: ServiceStatus.unknown,
        name: 'Boltz',
      ),
      payjoin: online,
      pricer: online,
      mempool: online,
    );

    expect(status.allServicesOnline, isTrue);
    expect(status.hasAnyServiceOffline, isFalse);
  });
}
