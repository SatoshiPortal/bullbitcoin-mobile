import 'package:primitives/primitives.dart';

/// Why a view operation did not happen. Nothing changed.
sealed class ViewsFailure extends Failure {
  const ViewsFailure([super.logMessage]);
}

/// The app is locked or the view is no longer one this session opened.
final class ViewsUnavailableFailure extends ViewsFailure {
  const ViewsUnavailableFailure() : super('views unavailable');
}

/// The last view cannot be deleted.
final class ViewsLastViewFailure extends ViewsFailure {
  const ViewsLastViewFailure() : super('last view');
}

/// The view holds a seed no other view holds.
final class ViewsHoldsSecretsFailure extends ViewsFailure {
  const ViewsHoldsSecretsFailure() : super('view holds secrets');
}

/// The view in use cannot be deleted.
final class ViewsInUseFailure extends ViewsFailure {
  const ViewsInUseFailure() : super('view in use');
}

/// The name is empty, too long or on several lines.
final class ViewsInvalidNameFailure extends ViewsFailure {
  const ViewsInvalidNameFailure() : super('invalid name');
}

/// Anything else. The user sees a generic message, never the cause.
final class ViewsUnexpectedFailure extends ViewsFailure {
  const ViewsUnexpectedFailure() : super('unexpected');
}
