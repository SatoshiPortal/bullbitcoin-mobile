import 'package:secrets/storage.dart' show ViewId, ViewSummary;

import '../domain/views_failure.dart';

/// What the list shows. Immutable; [failure] is the last refusal, if any.
final class ViewsState {
  final List<ViewSummary> views;
  final ViewId? active;
  final bool busy;
  final ViewsFailure? failure;

  const ViewsState({
    this.views = const [],
    this.active,
    this.busy = false,
    this.failure,
  });

  /// [failure] is replaced when given, kept when omitted; pass `() => null`
  /// to clear it.
  ViewsState copyWith({
    List<ViewSummary>? views,
    ViewId? active,
    bool? busy,
    ViewsFailure? Function()? failure,
  }) => ViewsState(
    views: views ?? this.views,
    active: active ?? this.active,
    busy: busy ?? this.busy,
    failure: failure == null ? this.failure : failure(),
  );
}
