import 'package:bb_mobile/core/domain/entities/wallet.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'receive_event.dart';
part 'receive_state.dart';
part 'receive_bloc.freezed.dart';

class ReceiveBloc extends Bloc<ReceiveEvent, ReceiveState> {
  ReceiveBloc() : super(const ReceiveState.initial());
}
