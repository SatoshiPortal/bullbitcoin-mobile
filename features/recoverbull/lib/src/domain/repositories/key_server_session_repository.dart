import 'package:primitives/primitives.dart';
import 'package:meta/meta.dart';

import '../recoverbull_failure.dart';
import 'key_server_repository.dart';

abstract interface class KeyServerSessionRepository {
  @useResult
  Future<Result<KeyServerRepository, RecoverBullFailure>> open(
    Uri server, {
    bool restartEmbedded = false,
  });
}
