import 'package:bb_mobile/features/address_view/domain/usecases/add_address_label_usecase.dart';
import 'package:bb_mobile/features/address_view/domain/usecases/find_address_owner_usecase.dart';
import 'package:bb_mobile/features/address_view/domain/usecases/get_address_labels_usecase.dart';
import 'package:bb_mobile/features/address_view/domain/usecases/get_address_overview_usecase.dart';
import 'package:bb_mobile/features/address_view/presentation/address_explorer_state.dart';
import 'package:bb_mobile/features/wallet/public/wallet_facade.dart'
    show Network;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:primitives/primitives.dart' show Err, Ok;

class AddressExplorerCubit extends Cubit<AddressExplorerState> {
  final GetAddressOverviewUsecase _getAddressOverviewUsecase;
  final FindAddressOwnerUsecase _findAddressOwnerUsecase;
  final GetAddressLabelsUsecase _getAddressLabelsUsecase;
  final AddAddressLabelUsecase _addAddressLabelUsecase;

  AddressExplorerCubit({
    required String address,
    required Network network,
    required this._getAddressOverviewUsecase,
    required this._findAddressOwnerUsecase,
    required this._getAddressLabelsUsecase,
    required this._addAddressLabelUsecase,
  }) : super(AddressExplorerState(address: address, network: network));

  Future<void> load() async {
    await Future.wait([_loadOwnership(), _loadOverview()]);
  }

  Future<void> _loadOwnership() async {
    final result = await _findAddressOwnerUsecase.execute(state.address);
    if (isClosed) return;
    emit(
      state.withOwnership(switch (result) {
        Ok(:final value) => AddressOwnershipKnown(value),
        Err(:final failure) => AddressOwnershipUnavailable(failure),
      }),
    );
    await _loadLabels();
  }

  Future<void> addLabel(String label) async {
    final owner = state.owner;
    final text = label.trim();
    if (owner == null || text.isEmpty) return;
    final result = await _addAddressLabelUsecase.execute(
      address: state.address,
      label: text,
      walletId: owner.id,
    );
    if (isClosed) return;
    switch (result) {
      case Ok():
        await _loadLabels();
      case Err(:final failure):
        emit(state.withLabelFailure(failure));
    }
  }

  Future<void> _loadLabels() async {
    if (state.owner == null) return;
    final labels = await _getAddressLabelsUsecase.execute(state.address);
    if (isClosed) return;
    emit(state.withLabels(labels));
  }

  Future<void> _loadOverview() async {
    if (state.isLoadingOverview) return;
    emit(state.withOverviewLoading());
    final result = await _getAddressOverviewUsecase.execute(
      address: state.address,
      network: state.network,
    );
    if (isClosed) return;
    emit(switch (result) {
      Ok(:final value) => state.withOverview(value),
      Err(:final failure) => state.withOverviewFailure(failure),
    });
  }
}
