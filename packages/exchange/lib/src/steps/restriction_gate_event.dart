import 'package:meta/meta.dart';

@immutable
sealed class RestrictionGateEvent {
  const RestrictionGateEvent();
}

/// The context was loaded again (pull to refresh, back from support).
final class RestrictionReloaded extends RestrictionGateEvent {
  final bool restricted;

  const RestrictionReloaded({required this.restricted});
}

final class RestrictionLeavePressed extends RestrictionGateEvent {
  const RestrictionLeavePressed();
}
