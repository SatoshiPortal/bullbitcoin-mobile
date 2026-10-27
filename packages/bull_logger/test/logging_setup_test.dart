import 'dart:convert';
import 'dart:io';

import 'package:bull_logger/bull_logger.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  test(
    'writes foreground and background logs to the supplied directory',
    () async {
      final directory = await _createLogDirectory();

      final foreground = File(p.join(directory.path, 'bull_logs.tsv'));
      final background = File(
        p.join(directory.path, 'bull_background_logs.tsv'),
      );

      await initializeLogging(directory: directory);
      expect(log.logsFile.path, foreground.path);
      expect(await foreground.exists(), isTrue);
      expect(await background.exists(), isFalse);

      log.fine('foreground initialization marker');
      await log.flush();
      expect(
        await foreground.readAsString(),
        contains('foreground initialization marker'),
      );

      await initializeLogging(directory: directory, background: true);
      expect(log.logsFile.path, background.path);
      expect(await background.exists(), isTrue);

      log.fine('background initialization marker');
      await log.flush();
      expect(
        await background.readAsString(),
        contains('background initialization marker'),
      );
      expect(
        await foreground.readAsString(),
        isNot(contains('background initialization marker')),
      );
      expect(
        await background.readAsString(),
        isNot(contains('foreground initialization marker')),
      );
    },
  );

  test(
    'defers diagnostics and reads runtime bindings added after setup',
    () async {
      final directory = await _createLogDirectory();
      final runtime = DiagnosticRuntimeContext();
      final source = _DiagnosticSource(runtime);

      await initializeLogging(
        directory: directory,
        diagnosticContextSource: source,
      );
      await log.flush();

      expect(source.probes, isEmpty);
      expect(
        await log.logsFile.readAsString(),
        isNot(contains('context_version')),
      );

      var torLoads = 0;
      runtime.setTorLoader(() async {
        torLoads++;
        return const DiagnosticTorContext(
          source: 'test-runtime',
          state: 'running',
          transport: 'socks5',
          socksProxyConfigured: true,
        );
      });
      await log.refreshDiagnosticContext();

      expect(
        source.probes,
        unorderedEquals([
          'appVersion',
          'device',
          'resources',
          'networkTypes',
          'vpnStatus',
          'tor',
        ]),
      );
      expect(torLoads, 1);
      final line = (await log.logsFile.readAsLines()).singleWhere(
        (line) => line.contains('"context_version":1'),
      );
      final context = jsonDecode(line.split('\t')[2]) as Map<String, dynamic>;
      expect(context['app'], 'test-app+1');
      expect(context['system']['model'], 'test-device');
      expect(context['tor']['source'], 'test-runtime');
      expect(context['tor']['state'], 'running');
      expect(context['tor']['socks_proxy_configured'], isTrue);
    },
  );

  test(
    'omits diagnostic probes in background logging even with a source',
    () async {
      final directory = await _createLogDirectory();
      final source = _DiagnosticSource(DiagnosticRuntimeContext());

      await initializeLogging(
        directory: directory,
        background: true,
        diagnosticContextSource: source,
      );
      await log.refreshDiagnosticContext();

      expect(await log.currentDiagnosticLogLine(), isNull);
      expect(source.probes, isEmpty);
      expect(
        await log.logsFile.readAsString(),
        isNot(contains('context_version')),
      );
    },
  );
}

Future<Directory> _createLogDirectory() async {
  final directory = await Directory.systemTemp.createTemp('bull-logger-setup-');
  final previousLog = log;
  addTearDown(() async {
    await log.flush();
    log = Logger.replace(
      directory: previousLog.dir,
      background: previousLog.filename == 'bull_background_logs.tsv',
    );
    await directory.delete(recursive: true);
  });
  return directory;
}

final class _DiagnosticSource implements DiagnosticContextSource {
  final DiagnosticRuntimeContext runtime;
  final List<String> probes = [];

  _DiagnosticSource(this.runtime);

  @override
  Future<String> appVersion() async {
    probes.add('appVersion');
    return 'test-app+1';
  }

  @override
  Future<DiagnosticDeviceContext> device() async {
    probes.add('device');
    return const DiagnosticDeviceContext(
      platform: 'test-platform',
      osVersion: 'test-os',
      model: 'test-device',
    );
  }

  @override
  Future<int?> batteryLevel() async {
    probes.add('batteryLevel');
    return 80;
  }

  @override
  Future<List<String>> networkTypes() async {
    probes.add('networkTypes');
    return ['wifi'];
  }

  @override
  Future<String> vpnStatus() async {
    probes.add('vpnStatus');
    return 'inactive';
  }

  @override
  Future<DiagnosticResources> resources() async {
    probes.add('resources');
    return const DiagnosticResources(batteryAvailablePercent: 80);
  }

  @override
  Future<DiagnosticTorContext> tor() async {
    probes.add('tor');
    return runtime.loadTor();
  }
}
