import 'dart:async';
import 'dart:io';

import 'package:bull_recoverbull/src/domain/entities/decrypted_vault.dart';
import 'package:bull_recoverbull/src/domain/recoverbull_failure.dart' as core;
import 'package:bull_recoverbull/src/domain/recoverbull_tor_route.dart';
import 'package:bull_recoverbull/src/domain/recoverbull_failure.dart';
import 'package:bull_recoverbull/src/presentation/bloc.dart';
import 'package:bull_recoverbull/src/router/flow_type.dart';
import 'package:primitives/primitives.dart';
import 'package:flutter_test/flutter_test.dart';
import '../support/recoverbull_bloc_harness.dart';
import 'package:mocktail/mocktail.dart';
import 'package:bull_tor/tor.dart';

void main() {
  setUpAll(() {
    registerFallbackValue(MockEncryptedVault());
    registerFallbackValue(const DecryptedVault());
  });
  setUp(setUpRecoverBullBloc);
  tearDown(tearDownRecoverBullBloc);

  test('closing a pending route preparation still closes the bloc', () async {
    final preparation =
        Completer<Result<RecoverBullTorRoute, core.RecoverBullFailure>>();
    when(
      () => ensureRecoverBullTorSession.execute(
        restartEmbedded: any(named: 'restartEmbedded'),
      ),
    ).thenAnswer((_) => preparation.future);
    var routeClosed = 0;
    final route = testRoute(
      onClose: () async {
        routeClosed++;
        throw StateError('teardown');
      },
    );
    final bloc = buildBloc(flow: RecoverBullFlow.recoverVault);

    bloc.add(const OnTorInitialization());
    await pumpEventQueue();
    final closing = bloc.close();
    preparation.complete(Ok(route));

    await closing;
    expect(bloc.isClosed, isTrue);
    expect(routeClosed, 1);
  });
  group('Tor retry concurrency', () {
    test('drops a second retry while the first one is in flight', () async {
      final pending =
          Completer<Result<RecoverBullTorRoute, core.RecoverBullFailure>>();
      when(
        () => ensureRecoverBullTorSession.execute(restartEmbedded: true),
      ).thenAnswer((_) => pending.future);
      final bloc = buildBloc(flow: RecoverBullFlow.recoverVault);

      bloc.add(const OnTorInitialization(restart: true));
      await pumpEventQueue();
      bloc.add(const OnTorInitialization(restart: true));
      await pumpEventQueue();

      verify(
        () => ensureRecoverBullTorSession.execute(restartEmbedded: true),
      ).called(1);

      pending.complete(const Err(core.KeyServerUnavailableFailure()));
      await pumpEventQueue();

      expect(bloc.state.failure, isA<TorNotStartedFailure>());
      await bloc.close();
    });
  });

  group('RecoverBull Tor readiness', () {
    test(
      'keeps a usable route ready during Arti directory refreshes',
      () async {
        final states = StreamController<TorConnectionState>();
        when(() => watchTor.execute()).thenAnswer((_) => states.stream);
        final bloc = buildBloc(flow: RecoverBullFlow.recoverVault);
        final route = TorRoute(
          source: TorSource.embedded,
          endpoint: TorProxyEndpoint(host: '127.0.0.1', port: 41001),
          evidence: TorReadinessEvidence.embeddedBootstrap,
          transport: TorTransport.direct,
        );

        states.add(
          const TorConnecting(
            source: TorSource.embedded,
            progress: 0.76,
            transport: TorTransport.direct,
          ),
        );
        await pumpEventQueue();
        states.add(TorReady(route));
        await pumpEventQueue();
        states.add(
          const TorConnecting(
            source: TorSource.embedded,
            progress: 0.42,
            transport: TorTransport.direct,
          ),
        );
        await pumpEventQueue();

        expect(bloc.state.torConnection, isA<TorReady>());

        states.add(
          const TorUnavailable(
            source: TorSource.embedded,
            failure: TorBootstrapFailure('route lost'),
          ),
        );
        await pumpEventQueue();
        expect(bloc.state.torConnection, isA<TorUnavailable>());

        await states.close();
        await bloc.close();
      },
    );

    test('surfaces a blockage after a previously ready route', () async {
      final states = StreamController<TorConnectionState>();
      when(() => watchTor.execute()).thenAnswer((_) => states.stream);
      final bloc = buildBloc(flow: RecoverBullFlow.recoverVault);
      final route = TorRoute(
        source: TorSource.embedded,
        endpoint: TorProxyEndpoint(host: '127.0.0.1', port: 41001),
        evidence: TorReadinessEvidence.embeddedBootstrap,
        transport: TorTransport.direct,
      );
      states.add(TorReady(route));
      await pumpEventQueue();
      states.add(
        const TorConnecting(
          source: TorSource.embedded,
          progress: 0.42,
          transport: TorTransport.direct,
          diagnostic: TorDiagnostic.offline,
        ),
      );
      await pumpEventQueue();

      expect(
        bloc.state.torConnection,
        const TorConnecting(
          source: TorSource.embedded,
          progress: 0.42,
          transport: TorTransport.direct,
          diagnostic: TorDiagnostic.offline,
        ),
      );

      await states.close();
      await bloc.close();
    });

    test(
      'acquires one flow route when readiness precedes initialization',
      () async {
        final states = StreamController<TorConnectionState>();
        when(() => watchTor.execute()).thenAnswer((_) => states.stream);
        final bloc = buildBloc(flow: RecoverBullFlow.recoverVault);
        final route = TorRoute(
          source: TorSource.embedded,
          endpoint: TorProxyEndpoint(host: '127.0.0.1', port: 41001),
          evidence: TorReadinessEvidence.embeddedBootstrap,
          transport: TorTransport.direct,
        );
        var closeCount = 0;
        final recoverBullRoute = RecoverBullTorRoute(
          route,
          () async => closeCount++,
          HttpClient(),
        );
        when(
          () => ensureRecoverBullTorSession.execute(),
        ).thenAnswer((_) async => Ok(recoverBullRoute));
        when(
          () => checkConnection.execute(route: recoverBullRoute),
        ).thenAnswer((_) async => const Ok(true));

        states.add(TorReady(route));
        await pumpEventQueue();
        bloc.add(const OnTorInitialization());
        await pumpEventQueue();

        expect(bloc.state.keyServerStatus, KeyServerStatus.online);
        verify(() => ensureRecoverBullTorSession.execute()).called(1);
        verify(
          () => checkConnection.execute(route: recoverBullRoute),
        ).called(1);

        await states.close();
        await bloc.close();
        expect(closeCount, 1);
      },
    );

    test('does not dispatch a server check after the bloc closes', () async {
      final pending =
          Completer<Result<RecoverBullTorRoute, core.RecoverBullFailure>>();
      when(
        () => ensureRecoverBullTorSession.execute(),
      ).thenAnswer((_) => pending.future);
      final bloc = buildBloc(flow: RecoverBullFlow.recoverVault);
      final route = TorRoute(
        source: TorSource.embedded,
        endpoint: TorProxyEndpoint(host: '127.0.0.1', port: 41001),
        evidence: TorReadinessEvidence.embeddedBootstrap,
        transport: TorTransport.direct,
      );
      var closeCount = 0;

      bloc.add(const OnTorInitialization());
      await pumpEventQueue();
      final close = bloc.close();
      pending.complete(
        Ok(RecoverBullTorRoute(route, () async => closeCount++, HttpClient())),
      );
      await close;

      verifyNever(() => checkConnection.execute());
      expect(closeCount, 1);
    });

    test('external failure is not replaced by embedded stream state', () async {
      final states = StreamController<TorConnectionState>();
      when(() => watchTor.execute()).thenAnswer((_) => states.stream);
      when(() => ensureRecoverBullTorSession.execute()).thenAnswer(
        (_) async => const Err(core.ExternalTorProxyUnavailableFailure()),
      );
      final bloc = buildBloc(flow: RecoverBullFlow.recoverVault);

      bloc.add(const OnTorInitialization());
      await pumpEventQueue();
      expect(
        bloc.state.torConnection,
        isA<TorUnavailable>().having(
          (value) => value.source,
          'source',
          TorSource.external,
        ),
      );
      states.add(
        TorReady(
          TorRoute(
            source: TorSource.embedded,
            endpoint: TorProxyEndpoint(host: '127.0.0.1', port: 41001),
            evidence: TorReadinessEvidence.embeddedBootstrap,
            transport: TorTransport.direct,
          ),
        ),
      );
      await pumpEventQueue();
      expect(
        bloc.state.torConnection,
        isA<TorUnavailable>().having(
          (value) => value.source,
          'source',
          TorSource.external,
        ),
      );
      verifyNever(() => checkConnection.execute());
      await states.close();
      await bloc.close();
    });

    test(
      'external unavailability checks the retained external route',
      () async {
        final states = StreamController<TorConnectionState>();
        when(() => watchTor.execute()).thenAnswer((_) => states.stream);
        final route = TorRoute(
          source: TorSource.external,
          endpoint: TorProxyEndpoint(host: '127.0.0.1', port: 41002),
          evidence: TorReadinessEvidence.externalSocksHandshake,
          transport: TorTransport.direct,
        );
        final recoverBullRoute = RecoverBullTorRoute(
          route,
          () async {},
          HttpClient(),
        );
        when(
          () => ensureRecoverBullTorSession.execute(),
        ).thenAnswer((_) async => Ok(recoverBullRoute));
        when(
          () => checkConnection.execute(route: recoverBullRoute),
        ).thenAnswer((_) async => const Ok(false));
        final bloc = buildBloc(flow: RecoverBullFlow.recoverVault);

        bloc.add(const OnTorInitialization());
        await pumpEventQueue();
        clearInteractions(checkConnection);
        states.add(
          const TorUnavailable(
            source: TorSource.external,
            failure: TorExternalProxyUnavailableFailure(),
          ),
        );
        await pumpEventQueue();

        verify(
          () => checkConnection.execute(route: recoverBullRoute),
        ).called(3);
        await states.close();
        await bloc.close();
      },
    );
  });
}
