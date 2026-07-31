import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';
import 'dart:typed_data';

import 'package:bb_mobile/core/entropy/domain/entropy_source.dart';

/// Dynamic environment snapshot, the mobile analog of Bitcoin Core's
/// `RandAddDynamicEnv`: process memory, high-resolution clocks and — on
/// Android — the process/system stat files the app can read about itself.
/// Individually low-entropy, but additive and free.
class SystemStatsSource implements EntropySource {
  const SystemStatsSource();

  static const _androidProcFiles = [
    '/proc/self/stat',
    '/proc/self/status',
    '/proc/stat',
    '/proc/meminfo',
    '/proc/uptime',
    '/proc/loadavg',
  ];

  @override
  String get name => EntropySourceName.systemStats;

  @override
  bool get mandatory => false;

  @override
  Future<Uint8List> collect() async {
    final builder = BytesBuilder(copy: false);
    final stopwatch = Stopwatch()..start();

    void addInt(int value) {
      final bytes = Uint8List(8);
      ByteData.view(bytes.buffer).setUint64(0, value);
      builder.add(bytes);
    }

    addInt(DateTime.now().microsecondsSinceEpoch);
    addInt(developer.Timeline.now);
    addInt(ProcessInfo.currentRss);
    addInt(ProcessInfo.maxRss);
    addInt(pid);
    builder.add(utf8.encode(Platform.operatingSystemVersion));
    builder.add(utf8.encode(Platform.localeName));
    addInt(Platform.numberOfProcessors);

    if (Platform.isAndroid) {
      for (final path in _androidProcFiles) {
        try {
          builder.add(await File(path).readAsBytes());
        } catch (_) {
          // Not readable on this device/OS version: skip, never substitute.
        }
        addInt(stopwatch.elapsedTicks);
      }
    }

    addInt(stopwatch.elapsedTicks);
    return builder.takeBytes();
  }
}
