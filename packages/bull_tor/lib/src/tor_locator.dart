import 'package:get_it/get_it.dart';

import 'data/dart_io_socket_adapter.dart';
import 'data/external_socks_tor_backend.dart';
import 'data/onion_tor_backend.dart';
import 'data/tor_http_client_factory.dart';
import 'data/tor_logger.dart';
import 'data/tor_repository_impl.dart';
import 'domain/ports/embedded_tor_port.dart';
import 'domain/ports/external_tor_port.dart';
import 'domain/ports/socket_port.dart';
import 'domain/entities/tor_transport.dart';
import 'domain/tor_repository.dart';
import 'domain/usecases/close_tor_usecase.dart';
import 'domain/usecases/ensure_tor_ready_usecase.dart';
import 'domain/usecases/get_tor_connection_usecase.dart';
import 'domain/usecases/get_tor_transport_mode_usecase.dart';
import 'domain/usecases/open_tor_session_usecase.dart';
import 'domain/usecases/retry_tor_connection_usecase.dart';
import 'domain/usecases/set_tor_dormant_usecase.dart';
import 'domain/usecases/set_tor_transport_mode_usecase.dart';
import 'domain/usecases/verify_external_tor_usecase.dart';
import 'domain/usecases/watch_tor_connection_usecase.dart';
import 'tor_lifecycle_controller.dart';
import 'tor_controller.dart';

/// Wires the package into the host app's service locator.
///
/// Two independent capabilities are registered here and they never meet:
/// the embedded Arti client behind [TorRepository], and the SOCKS check for
/// a user-managed local SOCKS5 proxy behind [VerifyExternalTorUsecase].
final class TorLocator {
  static Future<void> registerDatasources(
    GetIt locator, {
    TorLogger logger = const TorLogger(),
  }) async {
    await OnionTorBackend.initialize();
    locator.registerSingleton<TorLogger>(logger);
    locator.registerLazySingleton<SocketPort>(DartIoSocketAdapter.new);
    locator.registerLazySingleton<EmbeddedTorPort>(
      () => OnionTorBackend(locator<TorLogger>()),
    );
    locator.registerLazySingleton<ExternalTorPort>(
      () =>
          ExternalSocksTorBackend(locator<SocketPort>(), locator<TorLogger>()),
    );
    locator.registerLazySingleton<TorHttpClientFactory>(
      TorHttpClientFactory.new,
    );
  }

  static void registerRepositories(
    GetIt locator, {
    TorTransportMode initialMode = TorTransportMode.automatic,
    TorTransport? lastSuccessfulTransport,
    Future<void> Function(TorTransport)? onSuccessfulTransport,
  }) {
    locator.registerLazySingleton<TorRepository>(
      () => TorRepositoryImpl(
        locator<EmbeddedTorPort>(),
        initialMode: initialMode,
        lastSuccessfulTransport: lastSuccessfulTransport,
        onSuccessfulTransport: onSuccessfulTransport,
      ),
    );
  }

  static void registerUsecases(GetIt locator) {
    locator.registerFactory<EnsureTorReadyUsecase>(
      () => EnsureTorReadyUsecase(locator<TorRepository>()),
    );
    locator.registerFactory<RetryTorConnectionUsecase>(
      () => RetryTorConnectionUsecase(locator<TorRepository>()),
    );
    locator.registerFactory<WatchTorConnectionUsecase>(
      () => WatchTorConnectionUsecase(locator<TorRepository>()),
    );
    locator.registerFactory<SetTorDormantUsecase>(
      () => SetTorDormantUsecase(locator<TorRepository>()),
    );
    locator.registerFactory<VerifyExternalTorUsecase>(
      () => VerifyExternalTorUsecase(locator<ExternalTorPort>()),
    );
    locator.registerFactory<CloseTorUsecase>(
      () => CloseTorUsecase(locator<TorRepository>()),
    );
    locator.registerFactory<GetTorConnectionUsecase>(
      () => GetTorConnectionUsecase(locator<TorRepository>()),
    );
    locator.registerFactory<GetTorTransportModeUsecase>(
      () => GetTorTransportModeUsecase(locator<TorRepository>()),
    );
    locator.registerFactory<OpenTorSessionUsecase>(
      () => OpenTorSessionUsecase(locator<TorRepository>()),
    );
    locator.registerFactory<SetTorTransportModeUsecase>(
      () => SetTorTransportModeUsecase(locator<TorRepository>()),
    );
    locator.registerLazySingleton<Tor>(
      () => Tor(
        EmbeddedTor(
          locator<GetTorConnectionUsecase>(),
          locator<GetTorTransportModeUsecase>(),
          locator<EnsureTorReadyUsecase>(),
          locator<RetryTorConnectionUsecase>(),
          locator<WatchTorConnectionUsecase>(),
          locator<SetTorTransportModeUsecase>(),
          TorSessions(locator<OpenTorSessionUsecase>()),
        ),
        ExternalTor(locator<VerifyExternalTorUsecase>()),
        locator<CloseTorUsecase>(),
      ),
    );
    locator.registerLazySingleton<TorLifecycleController>(
      () => TorLifecycleController(
        locator<SetTorDormantUsecase>(),
        locator<TorLogger>(),
      ),
    );
  }
}
