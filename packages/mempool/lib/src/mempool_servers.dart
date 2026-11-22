part of 'mempool.dart';

/// Local configuration and connectivity checks for Mempool servers.
class MempoolServerSettings {
  final MempoolServerRepository _repository;
  final GetActiveMempoolServerUsecase _activeServer;
  final MempoolServerValidatorPort _validator;

  const MempoolServerSettings._({
    required this._repository,
    required this._activeServer,
    required this._validator,
  });

  @useResult
  Future<Result<MempoolServerSelection, MempoolFailure>> fetch({
    required Network network,
  }) async {
    final supported = MempoolServerNetwork.fromNetwork(network);
    if (supported == null) {
      return Err(MempoolUnsupportedNetworkFailure(network));
    }
    return LoadMempoolServerDataUsecase(serverRepository: _repository)
        .execute(supported);
  }

  /// Validates and replaces the custom server for its network.
  @useResult
  Future<Result<void, MempoolFailure>> store(MempoolServer server) async {
    final supported = MempoolServerNetwork.fromNetwork(server.network);
    if (supported == null) {
      return Err(MempoolUnsupportedNetworkFailure(server.network));
    }
    return SetCustomMempoolServerUsecase(
      serverRepository: _repository,
      validator: _validator,
    ).execute(server, network: supported);
  }

  @useResult
  Future<Result<void, MempoolFailure>> trash({required Network network}) async {
    final supported = MempoolServerNetwork.fromNetwork(network);
    if (supported == null) {
      return Err(MempoolUnsupportedNetworkFailure(network));
    }
    return _repository.deleteCustomServer(supported);
  }

  @useResult
  Future<Result<void, MempoolFailure>> validate(MempoolServer server) async {
    final network = MempoolServerNetwork.fromNetwork(server.network);
    if (network == null) {
      return Err(MempoolUnsupportedNetworkFailure(server.network));
    }
    return _validator.validateServer(
      url: server.url,
      network: network,
      enableSsl: server.enableSsl,
    );
  }

  /// Base URL for Bitcoin fee estimates. A failed custom lookup stops selection.
  @useResult
  Future<Result<Uri, MempoolFailure>> activeBase({
    required BitcoinNetwork network,
  }) async {
    return switch (await _activeServer.execute(network)) {
      Ok(:final value) => _parseMempoolUri(value.fullUrl),
      Err(:final failure) => Err(failure),
    };
  }
}
