import 'package:bb_mobile/features/app_startup/app_locator.dart';
import 'package:bb_mobile/features/receive/presentation/bloc/receive_bloc.dart';

class ReceiveLocator {
  static void setup() {
    // Bloc
    locator.registerFactory<ReceiveBloc>(() => ReceiveBloc());
  }
}
