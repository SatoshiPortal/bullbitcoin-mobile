import 'package:bull_tor/tor.dart';
import 'package:drift/drift.dart';
import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';

import 'data/drift_mempool_server_repository.dart';
import 'data/http_mempool_server_validator.dart';
import 'data/mempool_dao.dart';
import 'data/mempool_tor_session_adapter.dart';
import 'domain/entities/mempool_server.dart';
import 'domain/mempool_failure.dart';
import 'domain/models/mempool_server_dto.dart';
import 'domain/models/requests/delete_custom_mempool_server_request.dart';
import 'domain/models/requests/load_mempool_server_data_request.dart';
import 'domain/models/requests/set_custom_mempool_server_request.dart';
import 'domain/models/responses/load_mempool_server_data_response.dart';
import 'domain/ports/environment_port.dart';
import 'domain/ports/mempool_server_validator_port.dart';
import 'domain/repositories/mempool_server_repository.dart';
import 'domain/services/mempool_url_builder.dart';
import 'domain/usecases/delete_custom_mempool_server_usecase.dart';
import 'domain/usecases/get_active_mempool_server_usecase.dart';
import 'domain/usecases/load_mempool_server_data_usecase.dart';
import 'domain/usecases/set_custom_mempool_server_usecase.dart';
import 'domain/value_objects/mempool_server_network.dart';

/// Configured servers and explorer links for Bitcoin and Liquid.
class Mempool {
  final MempoolServerRepository _repository;
  final MempoolServerValidatorPort _validator;
  final MempoolEnvironmentPort _environment;

  factory Mempool({
    required GeneratedDatabase database,
    required MempoolEnvironmentPort environment,
    required Tor Function() tor,
    required TorHttpClientFactory torHttpClientFactory,
  }) => Mempool._(
    repository: DriftMempoolServerRepository(
      mempoolServerStorageDatasource: MempoolDao(database),
    ),
    validator: HttpMempoolServerValidator(
      torSessionPort: MempoolTorSessionAdapter(tor),
      torHttpClientFactory: torHttpClientFactory,
    ),
    environment: environment,
  );

  Mempool._({
    required this._repository,
    required this._validator,
    required this._environment,
  });

  late final MempoolUrlBuilder _urls = MempoolUrlBuilder(
    getActiveServer: GetActiveMempoolServerUsecase(
      serverRepository: _repository,
    ).execute,
  );

  MempoolUrlBuilder get urls => _urls;

  @useResult
  Future<Result<MempoolServer?, MempoolFailure>> customServer(
    MempoolServerNetwork network,
  ) => _repository.fetchCustomServer(network);

  @useResult
  Future<Result<MempoolServer, MempoolFailure>> defaultServer(
    MempoolServerNetwork network,
  ) => _repository.fetchDefaultServer(network);

  @useResult
  Future<Result<LoadMempoolServerDataResponse, MempoolFailure>> loadServers(
    LoadMempoolServerDataRequest request,
  ) => LoadMempoolServerDataUsecase(
    serverRepository: _repository,
    environmentPort: _environment,
  ).execute(request);

  @useResult
  Future<Result<void, MempoolFailure>> setCustomServer(
    SetCustomMempoolServerRequest request,
  ) => SetCustomMempoolServerUsecase(
    serverRepository: _repository,
    validator: _validator,
    environmentPort: _environment,
  ).execute(request);

  @useResult
  Future<Result<void, MempoolFailure>> deleteCustomServer(
    DeleteCustomMempoolServerRequest request,
  ) => DeleteCustomMempoolServerUsecase(
    serverRepository: _repository,
    environmentPort: _environment,
  ).execute(request);

  @useResult
  Future<Result<void, MempoolFailure>> validateServer(
    MempoolServerDto server,
  ) => _validator.validateServer(
    url: server.url,
    network: MempoolServerNetwork.fromEnvironment(
      isTestnet: server.isTestnet,
      isLiquid: server.isLiquid,
    ),
    enableSsl: server.enableSsl,
  );
}
