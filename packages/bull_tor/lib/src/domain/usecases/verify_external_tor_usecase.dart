import '../entities/tor_connection_state.dart';
import '../entities/tor_proxy_endpoint.dart';
import '../entities/tor_route.dart';
import '../ports/external_tor_port.dart';
import '../tor_failure.dart';

final class VerifyExternalTorUsecase {
  final ExternalTorPort _externalTor;

  const VerifyExternalTorUsecase(this._externalTor);

  Future<TorConnectionState> execute(TorProxyEndpoint endpoint) async {
    try {
      await _externalTor.verify(endpoint);
      return TorReady(
        TorRoute(
          source: TorSource.external,
          endpoint: endpoint,
          evidence: TorReadinessEvidence.externalSocksHandshake,
        ),
      );
    } on TorBackendException catch (error) {
      return TorUnavailable(source: TorSource.external, failure: error.failure);
    } catch (error) {
      return TorUnavailable(
        source: TorSource.external,
        failure: TorExternalProxyUnavailableFailure(error.toString()),
      );
    }
  }
}
