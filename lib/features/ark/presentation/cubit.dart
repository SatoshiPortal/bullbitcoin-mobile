import 'package:ark_wallet/ark_wallet.dart';
import 'package:bb_mobile/features/ark/presentation/state.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class ArkCubit extends Cubit<ArkState> {
  final ArkWallet wallet;

  ArkCubit({required this.wallet}) : super(const ArkState());
}
