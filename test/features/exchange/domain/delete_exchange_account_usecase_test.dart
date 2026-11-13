import 'dart:async';

import 'package:bb_mobile/features/exchange/domain/exchange_access.dart';
import 'package:bb_mobile/features/exchange/domain/exchange_failure.dart';
import 'package:bb_mobile/features/exchange/domain/repositories/exchange_access_repository.dart';
import 'package:bb_mobile/features/exchange/domain/usecases/delete_exchange_account_usecase.dart';
import 'package:bb_mobile/features/exchange/domain/usecases/request_exchange_account_deletion_usecase.dart';
import 'package:bb_mobile/features/exchange/domain/usecases/sign_out_exchange_usecase.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:primitives/primitives.dart';

class _Access extends Mock implements ExchangeAccessRepository {}

class _Request extends Mock implements RequestExchangeAccountDeletionUsecase {}

class _SignOut extends Mock implements SignOutExchangeUsecase {}

void main() {
  late _Access access;
  late _Request request;
  late _SignOut signOut;
  late DeleteExchangeAccountUsecase usecase;
  var epoch = 1;
  setUp(() {
    epoch = 1;
    access = _Access();
    request = _Request();
    signOut = _SignOut();
    when(
      () => access.current,
    ).thenReturn(const ExchangeAccessEnabled(ExchangeAccessSession.signedIn));
    when(() => access.epoch).thenAnswer((_) => epoch);
    usecase = DeleteExchangeAccountUsecase(request, signOut, access);
  });

  test('a failed request never signs out', () async {
    when(request.execute).thenAnswer(
      (_) async => const Err(ExchangeAccountDeletionRequestFailure()),
    );
    expect(
      (await usecase.execute() as Err).failure,
      isA<ExchangeAccountDeletionRequestFailure>(),
    );
    verifyNever(signOut.execute);
  });

  test('a sign-out failure is returned', () async {
    when(request.execute).thenAnswer((_) async => const Ok(null));
    when(
      signOut.execute,
    ).thenAnswer((_) async => const Err(ExchangeSessionClearFailure()));
    expect(
      (await usecase.execute() as Err).failure,
      isA<ExchangeSessionClearFailure>(),
    );
  });

  test('a completed request and sign-out report completion', () async {
    when(request.execute).thenAnswer((_) async => const Ok(null));
    when(signOut.execute).thenAnswer((_) async => const Ok(null));
    expect(
      (await usecase.execute() as Ok).value,
      ExchangeAccountDeletionOutcome.completed,
    );
  });

  test('an old deletion request cannot sign out the new session', () async {
    final pending = Completer<Result<void, ExchangeFailure>>();
    when(request.execute).thenAnswer((_) => pending.future);
    final result = usecase.execute();
    epoch++;
    pending.complete(const Ok(null));
    expect((await result as Ok).value, ExchangeAccountDeletionOutcome.stale);
    verifyNever(signOut.execute);
  });
}
