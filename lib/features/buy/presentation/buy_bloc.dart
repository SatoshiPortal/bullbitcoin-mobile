import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'buy_event.dart';
part 'buy_state.dart';

part 'buy_bloc.freezed.dart';

class BuyBloc extends Bloc<BuyEvent, BuyState> {
  BuyBloc() : super(const BuyState()) {
    on<_BuyStarted>(_onStarted);
  }

  void _onStarted(_BuyStarted event, Emitter<BuyState> emit) {
    // Handle the started event
  }
}
