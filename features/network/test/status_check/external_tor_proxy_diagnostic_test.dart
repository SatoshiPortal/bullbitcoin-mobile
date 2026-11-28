import 'package:primitives/primitives.dart' show Ok, Err;
import 'package:preferences/preferences.dart';
import 'package:network/network.dart';
import 'package:bull_tor/tor.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockSettingsRepository extends Mock implements Preferences {}

class _MockTor extends Mock implements Tor {}

class _MockExternalTor extends Mock implements ExternalTor {}

class _FakeExternalTorPort {
  _FakeExternalTorPort(this.available);

  final bool available;
  int verificationCount = 0;
}

TorProxyPreferences settings({required bool useTorProxy, int port = 9050}) =>
    (useTorProxy: useTorProxy, torProxyPort: port);

void main() {
  setUpAll(() {
    registerFallbackValue(TorProxyEndpoint(host: '127.0.0.1', port: 9050));
  });

  ExternalTorProxyDiagnostic usecase(
    _MockSettingsRepository repository,
    _FakeExternalTorPort port,
  ) {
    final tor = _MockTor();
    final external = _MockExternalTor();
    when(() => tor.external).thenReturn(external);
    when(() => external.verify(any())).thenAnswer((invocation) async {
      port.verificationCount++;
      final endpoint =
          invocation.positionalArguments.single as TorProxyEndpoint;
      if (!port.available) {
        return const TorUnavailable(
          source: TorSource.external,
          failure: TorExternalProxyUnavailableFailure(),
        );
      }
      return TorReady(
        TorRoute(
          source: TorSource.external,
          endpoint: endpoint,
          evidence: TorReadinessEvidence.externalSocksHandshake,
        ),
      );
    });
    return ExternalTorProxyDiagnostic(repository, tor);
  }

  test('returns unavailable when the enabled proxy handshake fails', () async {
    final repository = _MockSettingsRepository();
    when(repository.readTorProxyPreferences)
        .thenAnswer((_) async => Ok(settings(useTorProxy: true)));
    final port = _FakeExternalTorPort(false);

    final status = await usecase(repository, port).check();

    expect(status, ExternalTorProxyStatus.unavailable);
  });

  test('returns available when the enabled proxy handshake succeeds', () async {
    final repository = _MockSettingsRepository();
    when(repository.readTorProxyPreferences)
        .thenAnswer((_) async => Ok(settings(useTorProxy: true)));
    final port = _FakeExternalTorPort(true);

    final status = await usecase(repository, port).check();

    expect(status, ExternalTorProxyStatus.available);
  });

  test('returns disabled without checking a disabled proxy', () async {
    final repository = _MockSettingsRepository();
    when(repository.readTorProxyPreferences)
        .thenAnswer((_) async => Ok(settings(useTorProxy: false)));
    final port = _FakeExternalTorPort(true);

    final status = await usecase(repository, port).check();

    expect(status, ExternalTorProxyStatus.disabled);
    expect(port.verificationCount, 0);
  });

  test('returns unavailable for an invalid enabled port', () async {
    final repository = _MockSettingsRepository();
    when(repository.readTorProxyPreferences)
        .thenAnswer((_) async => Ok(settings(useTorProxy: true, port: 0)));
    final port = _FakeExternalTorPort(true);

    final status = await usecase(repository, port).check();

    expect(status, ExternalTorProxyStatus.unavailable);
    expect(port.verificationCount, 0);
  });

  test('unreadable preferences are distinct from a failed handshake', () async {
    final repository = _MockSettingsRepository();
    when(repository.readTorProxyPreferences)
        .thenAnswer((_) async => const Err(PreferencesReadFailure()));
    final port = _FakeExternalTorPort(true);
    expect(
      await usecase(repository, port).check(),
      ExternalTorProxyStatus.unreadable,
    );
    expect(port.verificationCount, 0);
  });

  group('settings attention', () {
    // The user-visible route off a home warning: only a proxy that should work
    // and does not route the user to the proxy settings; a proxy that answers,
    // or one the user left off, keeps the Electrum settings as the fix.
    const attention = {
      ExternalTorProxyStatus.unavailable: true,
      ExternalTorProxyStatus.unreadable: true,
      ExternalTorProxyStatus.available: false,
      ExternalTorProxyStatus.disabled: false,
    };

    test('maps every proxy status, so a new status is covered', () {
      expect(attention.keys.toSet(), ExternalTorProxyStatus.values.toSet());
    });

    for (final MapEntry(key: status, value: needsAttention)
        in attention.entries) {
      test('${status.name} needs settings attention: $needsAttention', () {
        expect(status.needsSettingsAttention, needsAttention);
      });
    }
  });
}
