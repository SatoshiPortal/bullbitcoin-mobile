import 'package:primitives/primitives.dart';

sealed class QuickActionsFailure extends Failure {
  const QuickActionsFailure([super.logMessage]);
}

final class QuickActionsStorageFailure extends QuickActionsFailure {
  const QuickActionsStorageFailure([super.logMessage]);
}
