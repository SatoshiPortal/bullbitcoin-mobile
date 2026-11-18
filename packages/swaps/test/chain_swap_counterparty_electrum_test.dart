import 'package:test/test.dart';
import 'package:swaps/src/data/boltz_api.dart';

void main() {
  group('storedElectrumSettings', () {
    test('plain tcp server is dialled without TLS', () {
      final s = BoltzDatasource.storedElectrumSettings('tcp://127.0.0.1:50001');
      expect(s.tls, isFalse);
      expect(s.url, 'tcp://127.0.0.1:50001');
    });

    test('ssl server keeps TLS', () {
      final s = BoltzDatasource.storedElectrumSettings('ssl://host:50002');
      expect(s.tls, isTrue);
    });
  });
}
