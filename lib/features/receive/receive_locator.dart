import 'package:bb_mobile/app_locator.dart';
import 'package:bb_mobile/features/receive/presentation/bloc/receive_bloc.dart';

class ReceiveLocator {
  static void setup() {
    // Bloc
    locator.registerFactory<ReceiveBloc>(() => ReceiveBloc());
  }
}
