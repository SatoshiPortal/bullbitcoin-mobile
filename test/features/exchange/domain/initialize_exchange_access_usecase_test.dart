import 'dart:async';

import 'package:bb_mobile/core/exchange/domain/exchange_api_key_failure.dart';
import 'package:bb_mobile/core/exchange/domain/repositories/exchange_api_key_repository.dart';
import 'package:bb_mobile/features/exchange/domain/exchange_session.dart';
import 'package:bb_mobile/features/exchange/domain/exchange_failure.dart';
import 'package:bb_mobile/features/exchange/domain/usecases/initialize_exchange_access_usecase.dart';
import 'package:bb_mobile/features/exchange_access/public/exchange_access_facade.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Keys extends Mock implements ExchangeApiKeyRepository {}

void main() {
  test(
    'environment change closes authentication before reading the new key',
    () async {
      SharedPreferences.setMockInitialValues({});
      final access = ExchangeAccessFacade();
      expect(
        await access.initialize(
          isTestnet: false,
          session: ExchangeSessionFact.authenticated,
        ),
        isA<Ok<ExchangeAccessOutcome, ExchangeAccessFailure>>(),
      );
      final keys = _Keys();
      final read = Completer<Result<String?, ExchangeApiKeyFailure>>();
      when(
        () => keys.readActiveApiKey(isTestnet: true),
      ).thenAnswer((_) => read.future);
      final usecase = InitializeExchangeAccessUsecase(
        ExchangeSession(keys),
        access,
      );
      final pending = usecase.execute(isTestnet: true);
      expect(access.current.canUseAuthenticatedExchange, isFalse);
      expect(access.current.enabledForHome, isTrue);
      read.complete(const Ok(null));
      expect(await pending, isA<Ok<void, ExchangeFailure>>());
      expect(access.current.choice, ExchangeAccessChoice.disabled);
      await access.dispose();
    },
  );
}
