import 'package:bull_swap/src/data/db/swap_database.dart';

abstract interface class SwapLegacyDataPort {
  Future<List<SwapsCompanion>> readSwaps();
  Future<List<AutoSwapCompanion>> readAutoSwaps();
  Future<List<OrderSwapsCompanion>> readOrderSwaps();
}
