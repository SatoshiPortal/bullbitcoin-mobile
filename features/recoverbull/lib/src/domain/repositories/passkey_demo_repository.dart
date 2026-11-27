import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';

import '../passkey_demo_operation.dart';

enum PasskeyDemoFailure implements Failure {
  disabled,
  cancelled,
  unavailable;

  @override
  String? get logMessage => null;
}

abstract interface class PasskeyDemoRepository {
  @useResult
  Future<Result<String, PasskeyDemoFailure>> register(
    PasskeyDemoOperation operation,
  );
  @useResult
  Future<Result<String, PasskeyDemoFailure>> open(
    String accountId,
    PasskeyDemoOperation operation,
  );
}
