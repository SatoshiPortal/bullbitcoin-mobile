import 'dart:convert';
import 'dart:io';

import 'package:battery_plus/battery_plus.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// The deliberately small, non-identifying context attached to support logs.
final class DiagnosticContext {
  final String app;
  final Map<String, Object?> system;
  final Map<String, Object?> resources;
  final Map<String, Object?> network;
  final Map<String, Object?> tor;

  const DiagnosticContext({
    required this.app,
    required this.system,
    required this.resources,
    required this.network,
    required this.tor,
  });

  String toLogMessage() => jsonEncode({
    'context_version': 1,
    'app': app,
    'system': system,
    'resources': resources,
    'network': network,
    'tor': tor,
  });
}

final class DiagnosticTorContext {
  final String? source;
  final String state;
  final String? transport;
  final int? progressPercent;
  final String? diagnostic;
  final bool socksProxyConfigured;

  const DiagnosticTorContext({
    this.source,
    required this.state,
    this.transport,
    this.progressPercent,
    this.diagnostic,
    this.socksProxyConfigured = false,
  });

  Map<String, Object?> toJson() => {
    'source': source,
    'state': state,
    'transport': transport,
    'progress_percent': _clampPercent(progressPercent),
    'diagnostic': diagnostic,
    'socks_proxy_configured': socksProxyConfigured,
  };
}

final class DiagnosticRuntimeContext {
  Future<DiagnosticTorContext> Function()? _torLoader;

  void setTorLoader(Future<DiagnosticTorContext> Function() loader) {
    _torLoader = loader;
  }

  Future<DiagnosticTorContext> loadTor() async =>
      await _torLoader?.call() ??
      const DiagnosticTorContext(state: 'uninitialized');
}

final class DiagnosticDeviceContext {
  final String platform;
  final String osVersion;
  final String? manufacturer;
  final String? model;
  final int? ramTotalMb;
  final int? ramAvailableMb;
  final int? diskTotalBytes;
  final int? diskAvailableBytes;

  const DiagnosticDeviceContext({
    required this.platform,
    required this.osVersion,
    this.manufacturer,
    this.model,
    this.ramTotalMb,
    this.ramAvailableMb,
    this.diskTotalBytes,
    this.diskAvailableBytes,
  });
}

final class DiagnosticResources {
  final int? ramTotalMb;
  final int? ramAvailablePercent;
  final int? diskTotalMb;
  final int? diskAvailablePercent;
  final int? batteryAvailablePercent;

  const DiagnosticResources({
    this.ramTotalMb,
    this.ramAvailablePercent,
    this.diskTotalMb,
    this.diskAvailablePercent,
    this.batteryAvailablePercent,
  });

  DiagnosticResources merge(DiagnosticDeviceContext? device) =>
      DiagnosticResources(
        ramTotalMb: ramTotalMb ?? device?.ramTotalMb,
        ramAvailablePercent:
            ramAvailablePercent ??
            _availablePercent(device?.ramTotalMb, device?.ramAvailableMb),
        diskTotalMb: diskTotalMb ?? _megabytesFromBytes(device?.diskTotalBytes),
        diskAvailablePercent:
            diskAvailablePercent ??
            _availablePercent(
              device?.diskTotalBytes,
              device?.diskAvailableBytes,
            ),
        batteryAvailablePercent: batteryAvailablePercent,
      );

  Map<String, Object?> toJson() => {
    'ram_total_mb': ramTotalMb,
    'ram_available_percent': _clampPercent(ramAvailablePercent),
    'disk_total_mb': diskTotalMb,
    'disk_available_percent': _clampPercent(diskAvailablePercent),
    'battery_available_percent': _clampPercent(batteryAvailablePercent),
  };
}

abstract interface class DiagnosticContextSource {
  Future<String> appVersion();

  Future<DiagnosticDeviceContext> device();

  Future<int?> batteryLevel();

  Future<List<String>> networkTypes();

  Future<String> vpnStatus();

  Future<DiagnosticResources> resources();

  Future<DiagnosticTorContext> tor();
}

class DiagnosticContextProvider {
  final DiagnosticContextSource _source;
  final Duration probeTimeout;

  /// A two-second per-probe limit keeps diagnostics useful while preventing a
  /// stalled platform or Tor probe from blocking log sharing indefinitely.
  const DiagnosticContextProvider(
    this._source, {
    this.probeTimeout = const Duration(seconds: 2),
  });

  Future<DiagnosticContext> load() async {
    final probes = await Future.wait([
      _bestEffort(_source.appVersion),
      _bestEffort(_source.device),
      _bestEffort(_source.resources),
      _bestEffort(_source.networkTypes),
      _bestEffort(_source.vpnStatus),
      _bestEffort(_source.tor),
    ]);
    final app = probes[0] as String?;
    final device = probes[1] as DiagnosticDeviceContext?;
    final resources = probes[2] as DiagnosticResources?;
    final transports = probes[3] as List<String>?;
    final vpn = probes[4] as String?;
    final tor = probes[5] as DiagnosticTorContext?;

    return DiagnosticContext(
      app: app ?? 'unknown',
      system: {
        'platform': device?.platform ?? 'unknown',
        'os_version': device?.osVersion ?? 'unknown',
        'manufacturer': device?.manufacturer,
        'model': device?.model,
      },
      resources: (resources ?? const DiagnosticResources())
          .merge(device)
          .toJson(),
      network: {
        'transports': transports ?? const <String>[],
        'vpn': vpn ?? 'unknown',
      },
      tor: (tor ?? const DiagnosticTorContext(state: 'uninitialized')).toJson(),
    );
  }

  Future<T?> _bestEffort<T>(Future<T> Function() load) async {
    try {
      return await load().timeout(probeTimeout);
    } catch (_) {
      return null;
    }
  }
}

class PlatformDiagnosticContextSource implements DiagnosticContextSource {
  final DeviceInfoPlugin _deviceInfo;
  final Battery _battery;
  final Connectivity _connectivity;
  final DiagnosticRuntimeContext? runtime;

  PlatformDiagnosticContextSource({
    DeviceInfoPlugin? deviceInfo,
    Battery? battery,
    Connectivity? connectivity,
    this.runtime,
  }) : _deviceInfo = deviceInfo ?? DeviceInfoPlugin(),
       _battery = battery ?? Battery(),
       _connectivity = connectivity ?? Connectivity();

  @override
  Future<String> appVersion() async {
    final info = await PackageInfo.fromPlatform();
    return '${info.version}+${info.buildNumber}';
  }

  @override
  Future<int?> batteryLevel() async =>
      _clampPercent(await _battery.batteryLevel);

  @override
  Future<DiagnosticResources> resources() async =>
      DiagnosticResources(batteryAvailablePercent: await batteryLevel());

  @override
  Future<DiagnosticDeviceContext> device() async {
    if (Platform.isAndroid) {
      final info = await _deviceInfo.androidInfo;
      return DiagnosticDeviceContext(
        platform: 'android',
        osVersion:
            'Android ${info.version.release} (API ${info.version.sdkInt})',
        manufacturer: info.manufacturer,
        model: info.model,
        ramTotalMb: info.physicalRamSize,
        ramAvailableMb: info.availableRamSize,
        diskTotalBytes: info.totalDiskSize,
        diskAvailableBytes: info.freeDiskSize,
      );
    }
    if (Platform.isIOS) {
      final info = await _deviceInfo.iosInfo;
      return DiagnosticDeviceContext(
        platform: 'ios',
        osVersion: '${info.systemName} ${info.systemVersion}',
        manufacturer: 'Apple',
        model: info.modelName,
        ramTotalMb: info.physicalRamSize,
        ramAvailableMb: info.availableRamSize,
        diskTotalBytes: info.totalDiskSize,
        diskAvailableBytes: info.freeDiskSize,
      );
    }
    if (Platform.isLinux) {
      final info = await _deviceInfo.linuxInfo;
      return DiagnosticDeviceContext(
        platform: 'linux',
        osVersion: info.prettyName,
      );
    }
    if (Platform.isMacOS) {
      final info = await _deviceInfo.macOsInfo;
      return DiagnosticDeviceContext(
        platform: 'macos',
        osVersion:
            'macOS ${info.majorVersion}.${info.minorVersion}.${info.patchVersion}',
        manufacturer: 'Apple',
        model: info.model,
        ramTotalMb: _megabytesFromBytes(info.memorySize),
      );
    }
    if (Platform.isWindows) {
      final info = await _deviceInfo.windowsInfo;
      return DiagnosticDeviceContext(
        platform: 'windows',
        osVersion:
            '${info.productName} ${info.displayVersion} (build ${info.buildNumber})',
        ramTotalMb: info.systemMemoryInMegabytes,
      );
    }
    return DiagnosticDeviceContext(
      platform: Platform.operatingSystem,
      osVersion: Platform.operatingSystemVersion,
    );
  }

  @override
  Future<List<String>> networkTypes() async =>
      ((await _connectivity.checkConnectivity())
          .map((type) => type.name)
          .toSet()
          .toList()
        ..sort());

  @override
  Future<DiagnosticTorContext> tor() async =>
      await runtime?.loadTor() ??
      const DiagnosticTorContext(state: 'uninitialized');

  @override
  Future<String> vpnStatus() async {
    final transports = await _connectivity.checkConnectivity();
    if (transports.contains(ConnectivityResult.vpn)) return 'active';
    return switch (Platform.operatingSystem) {
      'android' || 'linux' || 'windows' => 'inactive',
      _ => 'unknown',
    };
  }
}

int? _clampPercent(int? value) => value == null
    ? null
    : value < 0
    ? 0
    : value > 100
    ? 100
    : value;

int? _megabytesFromBytes(int? bytes) =>
    bytes == null ? null : (bytes / (1024 * 1024)).round();

int? _availablePercent(num? total, num? available) =>
    total == null || available == null || total <= 0
    ? null
    : _clampPercent((available * 100 / total).round());
