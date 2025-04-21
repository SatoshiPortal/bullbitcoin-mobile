import 'package:bb_mobile/core/electrum/domain/entity/electrum_server.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

@freezed
part 'electrum_settings_bloc.freezed.dart';
part 'electrum_settings_event.dart';
part 'electrum_settings_state.dart';

sealed class ElectrumSettingsBloc
    extends Bloc<ElectrumSettingsEvent, ElectrumSettingsState> {
  ElectrumSettingsBloc() : super(const _Initial()) {
    on<ElectrumSettingsEvent>((event, emit) {
      // TODO: implement event handler
    });
  }
}
