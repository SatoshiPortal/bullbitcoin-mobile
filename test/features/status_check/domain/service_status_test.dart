import 'package:bb_mobile/features/status_check/domain/service_status.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('remaining services can be healthy without Boltz', () {
    const online = ServiceStatusInfo(
      status: ServiceStatus.online,
      name: 'service',
    );
    const status = AllServicesStatus(
      internetConnection: online,
      bitcoinElectrum: online,
      liquidElectrum: online,
      payjoin: online,
      pricer: online,
      mempool: online,
    );

    expect(status.allServicesOnline, isTrue);
    expect(status.hasAnyServiceOffline, isFalse);
  });
}
