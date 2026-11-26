import 'package:bull_exchange/src/settings/domain/entities/exchange_preferences.dart';
import 'package:bull_exchange/src/settings/domain/exchange_settings_failure.dart';
import 'package:bull_exchange/src/settings/domain/usecases/enable_exchange_access_usecase.dart';
import 'package:bull_exchange/src/settings/domain/usecases/get_exchange_preferences_usecase.dart';
import 'package:bull_exchange/src/settings/domain/usecases/update_exchange_preferences_usecase.dart';
import 'package:bull_exchange/src/settings/domain/usecases/get_exchange_access_usecase.dart';
import 'package:bull_exchange/src/settings/domain/usecases/resolve_exchange_access_usecase.dart';
import 'package:bull_exchange/src/settings/domain/usecases/sign_out_of_exchange_usecase.dart';
import 'package:bull_exchange/src/settings/domain/usecases/watch_exchange_access_usecase.dart';
import 'package:bull_exchange/src/settings/presentation/exchange_access_settings_bloc.dart';
import 'package:exchange/exchange.dart';
import 'package:primitives/primitives.dart';

typedef AccessAnswer = Future<Result<void, ExchangeFailure>> Function();

final class FakeGetExchangeAccessUsecase implements GetExchangeAccessUsecase {
  final ExchangeAccess Function() answer;

  FakeGetExchangeAccessUsecase(this.answer);

  @override
  ExchangeAccess execute() => answer();
}

final class FakeWatchExchangeAccessUsecase
    implements WatchExchangeAccessUsecase {
  final Stream<ExchangeAccess> Function() answer;

  FakeWatchExchangeAccessUsecase(this.answer);

  @override
  Stream<ExchangeAccess> execute() => answer();
}

final class FakeEnableExchangeAccessUsecase
    implements EnableExchangeAccessUsecase {
  final AccessAnswer answer;

  FakeEnableExchangeAccessUsecase(this.answer);

  @override
  Future<Result<void, ExchangeFailure>> execute() => answer();
}

final class FakeSignOutOfExchangeUsecase implements SignOutOfExchangeUsecase {
  final AccessAnswer answer;

  FakeSignOutOfExchangeUsecase(this.answer);

  @override
  Future<Result<void, ExchangeFailure>> execute() => answer();
}

final class FakeResolveExchangeAccessUsecase
    implements ResolveExchangeAccessUsecase {
  final AccessAnswer answer;

  FakeResolveExchangeAccessUsecase(this.answer);

  @override
  Future<Result<void, ExchangeFailure>> execute() => answer();
}

/// The access settings bloc over fakes. Every attempt it runs lands in
/// [calls] (`enable`, `signOut`, `resolve`); an attempt without an answer
/// throws.
ExchangeAccessSettingsBloc accessSettingsBloc({
  required ExchangeAccess Function() current,
  Stream<ExchangeAccess> changes = const Stream.empty(),
  List<String>? calls,
  AccessAnswer? enable,
  AccessAnswer? signOut,
  AccessAnswer? resolve,
}) {
  AccessAnswer logged(String name, AccessAnswer? answer) => () {
    calls?.add(name);
    if (answer == null) throw StateError('$name was not expected');
    return answer();
  };
  return ExchangeAccessSettingsBloc(
    getAccess: FakeGetExchangeAccessUsecase(current),
    watchAccess: FakeWatchExchangeAccessUsecase(() => changes),
    enableAccess: FakeEnableExchangeAccessUsecase(logged('enable', enable)),
    signOut: FakeSignOutOfExchangeUsecase(logged('signOut', signOut)),
    resolveAccess: FakeResolveExchangeAccessUsecase(logged('resolve', resolve)),
  );
}

final class FakeGetExchangePreferencesUsecase
    implements GetExchangePreferencesUsecase {
  final Future<Result<ExchangePreferences, ExchangeSettingsFailure>> Function()
  answer;

  FakeGetExchangePreferencesUsecase(this.answer);

  @override
  Future<Result<ExchangePreferences, ExchangeSettingsFailure>> execute() =>
      answer();
}

final class FakeUpdateExchangePreferencesUsecase
    implements UpdateExchangePreferencesUsecase {
  final Future<GatedWrite<Result<void, ExchangeSettingsFailure>>> Function(
    ExchangeSession? session, {
    required ExchangePreferences loaded,
    required ExchangePreferences edited,
  })
  answer;

  FakeUpdateExchangePreferencesUsecase(this.answer);

  @override
  Future<GatedWrite<Result<void, ExchangeSettingsFailure>>> execute(
    ExchangeSession? session, {
    required ExchangePreferences loaded,
    required ExchangePreferences edited,
  }) => answer(session, loaded: loaded, edited: edited);
}
