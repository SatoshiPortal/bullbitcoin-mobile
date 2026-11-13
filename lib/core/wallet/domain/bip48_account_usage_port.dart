import 'package:bb_mobile/core/wallet/domain/entities/bip48_account_usage.dart';

abstract interface class Bip48AccountUsagePort {
  Future<List<Bip48AccountUsage>> getBip48AccountUsages();
}
