import 'package:meta/meta.dart';
import 'package:ark/ark.dart';
import 'package:primitives/primitives.dart';

import '../ark_failure.dart';

abstract interface class ArkAccountRegistryRepository {
  @useResult
  Future<Result<void, ArkFailure>> publish(ArkAccountConfig config);
  @useResult
  Future<Result<List<ArkAccountConfig>, ArkFailure>> list();
}
