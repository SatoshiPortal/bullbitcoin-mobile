import 'package:bbx_api/bbx_api.dart' as bbx;
import 'package:primitives/primitives.dart';

import '../domain/catalog/jurisdiction.dart';
import '../domain/entities/funding_institution.dart';
import '../domain/exchange_access.dart';
import '../domain/exchange_call_result.dart';
import '../domain/exchange_failure.dart';
import '../domain/repositories/funding_repository.dart';
import '../funding/funding_request.dart';
import 'bbx_api_funding_rails.dart';
import 'exchange_call_classifier.dart';

/// Runs a call on a client of [session]'s environment.
typedef RunFundingOperation = Future<Result<T, ExchangeFailure>> Function<T>(
  ExchangeSession session,
  Future<Result<T, ExchangeFailure>> Function(bbx.Bbx) operation,
);

/// [FundingRepository] on the `bbx_api` package: each call runs
/// [BbxApiFundingRails] on a client of the flow's session.
final class BbxApiFundingRepository implements FundingRepository {
  final RunFundingOperation _read;
  final RunFundingOperation _write;
  final Uri _paymentReturnUrl;

  const BbxApiFundingRepository({
    required this._read,
    required this._write,
    required this._paymentReturnUrl,
  });

  BbxApiFundingRails _rails(bbx.Bbx client) =>
      BbxApiFundingRails(client, paymentReturnUrl: _paymentReturnUrl);

  Future<ExchangeRead<T>> _fundRead<T>(
    ExchangeSession session,
    Future<ExchangeRead<T>> Function(BbxApiFundingRails) call,
  ) async => switch (await _read<ExchangeRead<T>>(
    session,
    (client) async => Ok(await call(_rails(client))),
  )) {
    Ok(:final value) => value,
    Err(:final failure) => readOfFailure<T>(failure),
  };

  @override
  Future<ExchangeRead<FundingAccount>> account(ExchangeSession session) =>
      _fundRead(session, (rails) => rails.account());

  @override
  Future<ExchangeRead<FundingAnswer>> instructions(
    ExchangeSession session,
    FundingRequest request,
  ) => _fundRead(session, (rails) => rails.instructions(request));

  @override
  Future<ExchangeRead<List<FundingInstitution>>> institutions(
    ExchangeSession session,
    Jurisdiction jurisdiction,
  ) => _fundRead(session, (rails) => rails.institutions(jurisdiction));

  @override
  Future<ExchangeWrite<void>> consent(ExchangeSession session) async =>
      switch (await _write<ExchangeWrite<void>>(
        session,
        (client) async => Ok(await _rails(client).consent()),
      )) {
        Ok(:final value) => value,
        Err(:final failure) => writeNotRun<void>(failure),
      };

  @override
  Future<ExchangeRead<bool>> consentOnAccount(ExchangeSession session) =>
      _fundRead(session, (rails) => rails.consentOnAccount());
}
