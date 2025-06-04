import 'package:bb_mobile/features/buy/presentation/buy_bloc.dart';
import 'package:bb_mobile/locator.dart';

class BuyLocator {
  static void setup() {
    registerBlocs();
  }

  static void registerBlocs() {
    locator.registerFactory<BuyBloc>(() => BuyBloc());
  }
}
