import 'entities/recoverbull_network.dart';

abstract interface class RecoverBullLifecyclePort {
  Future<void> markStored(RecoverBullNetwork network);
  Future<void> markVerified(RecoverBullNetwork network);
}
