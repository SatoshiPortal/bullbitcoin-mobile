import 'package:bull_exchange/src/settings/domain/entities/exchange_document_to_upload.dart';
import 'package:bull_exchange/src/settings/domain/entities/exchange_preferences.dart';
import 'package:bull_exchange/src/settings/domain/entities/secure_file_upload.dart';
import 'package:bull_exchange/src/settings/domain/usecases/enable_exchange_access_usecase.dart';
import 'package:bull_exchange/src/settings/domain/usecases/get_exchange_preferences_usecase.dart';
import 'package:bull_exchange/src/settings/domain/usecases/get_secure_file_upload_status_usecase.dart';
import 'package:bull_exchange/src/settings/domain/usecases/pick_exchange_document_usecase.dart';
import 'package:bull_exchange/src/settings/domain/usecases/update_exchange_preferences_usecase.dart';
import 'package:bull_exchange/src/settings/domain/usecases/upload_exchange_document_usecase.dart';
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
  final Future<Result<ExchangePreferences, ExchangeFailure>> Function() answer;

  FakeGetExchangePreferencesUsecase(this.answer);

  @override
  Future<Result<ExchangePreferences, ExchangeFailure>> execute(
    ExchangeSession? session,
  ) => answer();
}

final class FakeUpdateExchangePreferencesUsecase
    implements UpdateExchangePreferencesUsecase {
  final Future<Result<void, ExchangeFailure>> Function(
    ExchangeSession? session, {
    required ExchangePreferences loaded,
    required ExchangePreferences edited,
  })
  answer;

  FakeUpdateExchangePreferencesUsecase(this.answer);

  @override
  Future<Result<void, ExchangeFailure>> execute(
    ExchangeSession? session, {
    required ExchangePreferences loaded,
    required ExchangePreferences edited,
  }) => answer(session, loaded: loaded, edited: edited);
}

final class FakeGetSecureFileUploadStatusUsecase
    implements GetSecureFileUploadStatusUsecase {
  final Future<Result<SecureFileUpload, ExchangeFailure>> Function() answer;

  FakeGetSecureFileUploadStatusUsecase(this.answer);

  @override
  Future<Result<SecureFileUpload, ExchangeFailure>> execute(
    ExchangeSession? session,
  ) => answer();
}

final class FakePickExchangeDocumentUsecase
    implements PickExchangeDocumentUsecase {
  final Future<Result<ExchangeDocumentToUpload?, ExchangeFailure>> Function({
    String? userId,
  })
  answer;

  FakePickExchangeDocumentUsecase(this.answer);

  @override
  Future<Result<ExchangeDocumentToUpload?, ExchangeFailure>> execute({
    String? userId,
  }) => answer(userId: userId);
}

final class FakeUploadExchangeDocumentUsecase
    implements UploadExchangeDocumentUsecase {
  final Future<Result<void, ExchangeFailure>> Function(
    ExchangeDocumentToUpload document,
  )
  answer;

  FakeUploadExchangeDocumentUsecase(this.answer);

  @override
  Future<Result<void, ExchangeFailure>> execute(
    ExchangeDocumentToUpload document,
  ) => answer(document);
}
