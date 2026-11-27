import 'package:primitives/primitives.dart';
import 'package:secrets/storage.dart' show ViewId, ViewSummary;

import 'views_failure.dart';

/// What the screens need of the views. The implementation answers for the live
/// session only, and knows nothing of a view the session did not open.
abstract interface class ViewsPort {
  /// The views the session opened, by name. Empty while locked.
  List<ViewSummary> get views;

  /// The view in use, or null while locked.
  ViewId? get active;

  /// Emits whenever the views, the view in use or the lock change.
  Stream<void> get changes;

  Future<Result<void, ViewsFailure>> activate(ViewId id);

  Future<Result<ViewSummary, ViewsFailure>> create(String name);

  Future<Result<void, ViewsFailure>> rename(ViewId id, String name);

  Future<Result<void, ViewsFailure>> delete(ViewId id);

  /// Whether the view in use lets background sync read its descriptors.
  Future<Result<void, ViewsFailure>> setBackground(bool enabled);
}
