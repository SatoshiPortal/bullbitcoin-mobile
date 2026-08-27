import 'dart:convert';

import 'package:bb_mobile/core/utils/diagnostic_context.dart';
import 'package:flutter_test/flutter_test.dart';

class _DiagnosticContextSource implements DiagnosticContextSource {
  final bool failBattery;

  const _DiagnosticContextSource({this.failBattery = false});

  @override
  Future<String> appVersion() async => '6.13.0+214';

  @override
  Future<int?> batteryLevel() async {
    if (failBattery) throw StateError('Battery unavailable');
    return 73;
  }

  @override
  Future<DiagnosticDeviceContext> device() async =>
      const DiagnosticDeviceContext(
        platform: 'android',
        osVersion: 'Android 14 (API 34)',
        manufacturer: 'Google',
        model: 'Pixel 5',
        ramTotalMb: 8000,
        ramAvailableMb: 2000,
        diskTotalBytes: 134217728000,
        diskAvailableBytes: 33554432000,
      );

  @override
  Future<List<String>> networkTypes() async => const ['mobile', 'vpn', 'wifi'];

  @override
  Future<DiagnosticResources> resources() async =>
      DiagnosticResources(batteryAvailablePercent: await batteryLevel());

  @override
  Future<DiagnosticTorContext> tor() async => const DiagnosticTorContext(
    source: 'external',
    state: 'ready',
    socksProxyConfigured: true,
  );

  @override
  Future<String> vpnStatus() async => 'active';
}

void main() {
  test('formats only the explicit diagnostic allowlist', () async {
    final context = await const DiagnosticContextProvider(
      _DiagnosticContextSource(),
    ).load();

    final json = jsonDecode(context.toLogMessage()) as Map<String, dynamic>;
    expect(json.keys, [
      'context_version',
      'app',
      'system',
      'resources',
      'network',
      'tor',
    ]);
    expect(json['context_version'], 1);
    expect(json['app'], '6.13.0+214');
    expect(json['system'], {
      'platform': 'android',
      'os_version': 'Android 14 (API 34)',
      'manufacturer': 'Google',
      'model': 'Pixel 5',
    });
    expect(json['resources'], {
      'ram_total_mb': 8000,
      'ram_available_percent': 25,
      'disk_total_mb': 128000,
      'disk_available_percent': 25,
      'battery_available_percent': 73,
    });
    expect(json['network'], {
      'transports': ['mobile', 'vpn', 'wifi'],
      'vpn': 'active',
    });
    expect(json['tor'], {
      'source': 'external',
      'state': 'ready',
      'transport': null,
      'progress_percent': null,
      'diagnostic': null,
      'socks_proxy_configured': true,
    });
    expect(context.toLogMessage(), isNot(contains('event')));
    expect(context.toLogMessage(), isNot(contains('machine_id')));
    expect(context.toLogMessage(), isNot(contains('identifier')));
    expect(context.toLogMessage(), isNot(contains('127.0.0.1')));
    expect(context.toLogMessage(), isNot(contains('9050')));
  });

  test('keeps collecting when an optional source is unavailable', () async {
    final context = await const DiagnosticContextProvider(
      _DiagnosticContextSource(failBattery: true),
    ).load();
    final json = jsonDecode(context.toLogMessage()) as Map<String, dynamic>;

    expect(json['app'], '6.13.0+214');
    expect((json['system'] as Map)['model'], 'Pixel 5');
    expect((json['resources'] as Map)['battery_available_percent'], isNull);
    expect((json['resources'] as Map)['ram_total_mb'], 8000);
  });

  test('clamps percentages without exposing available amounts', () {
    const resources = DiagnosticResources(
      ramTotalMb: 4096,
      ramAvailablePercent: 105,
      diskTotalMb: 128000,
      diskAvailablePercent: -1,
    );

    expect(resources.toJson(), {
      'ram_total_mb': 4096,
      'ram_available_percent': 100,
      'disk_total_mb': 128000,
      'disk_available_percent': 0,
      'battery_available_percent': null,
    });
    expect(resources.toJson().containsKey('ram_available_mb'), isFalse);
    expect(resources.toJson().containsKey('disk_available_mb'), isFalse);
  });
}
