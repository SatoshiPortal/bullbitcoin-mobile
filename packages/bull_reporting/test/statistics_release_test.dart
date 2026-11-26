import 'package:bull_reporting/statistics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

final class CountingNetwork implements StatisticsNetwork {
  int reads = 0;

  @override
  Stream<bool> get changes => const Stream.empty();

  @override
  Future<bool> isMainnet() async {
    reads++;
    return true;
  }
}

void main() {
  test(
    'debug initialization does not consult or initialize statistics',
    () async {
      expect(kReleaseMode, isFalse);
      final network = CountingNetwork();
      await Statistics.instance.start(
        dsn: 'http://public@127.0.0.1:1/1',
        network: network,
      );
      expect(network.reads, 0);
    },
  );
}
