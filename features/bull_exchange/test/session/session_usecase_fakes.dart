import 'package:bull_exchange/src/session/domain/usecases/get_announcements_usecase.dart';
import 'package:bull_exchange/src/session/domain/usecases/reconcile_unknown_writes_usecase.dart';
import 'package:exchange/exchange.dart';
import 'package:primitives/primitives.dart';

final class FakeGetAnnouncementsUsecase implements GetAnnouncementsUsecase {
  final Future<Result<List<Announcement>, ExchangeFailure>> Function(
    ExchangeSession session,
  )
  answer;

  FakeGetAnnouncementsUsecase(this.answer);

  @override
  Future<Result<List<Announcement>, ExchangeFailure>> execute(
    ExchangeSession session,
  ) => answer(session);
}

final class FakeReconcileUnknownWritesUsecase
    implements ReconcileUnknownWritesUsecase {
  final Future<Result<UnknownWriteReconciliation, Failure>> Function(
    ExchangeSession session,
  )
  answer;

  FakeReconcileUnknownWritesUsecase(this.answer);

  @override
  Future<Result<UnknownWriteReconciliation, Failure>> execute(
    ExchangeSession session,
  ) => answer(session);
}
