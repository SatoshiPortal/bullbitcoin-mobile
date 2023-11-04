import 'dart:convert';

import 'package:bb_mobile/_pkg/storage/hive.dart';
import 'package:bb_mobile/_pkg/storage/storage.dart';
import 'package:bb_mobile/network_fees/bloc/state.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class NetworkFeesCubit extends Cubit<NetworkFeesState> {
  NetworkFeesCubit({required this.hiveStorage}) : super(const NetworkFeesState()) {
    init();
  }

  final HiveStorage hiveStorage;

  @override
  void onChange(Change<NetworkFeesState> change) {
    super.onChange(change);
    hiveStorage.saveValue(
      key: StorageKeys.networkFees,
      value: jsonEncode(change.nextState.toJson()),
    );
  }

  Future<void> init() async {
    Future.delayed(const Duration(milliseconds: 200));
    final (result, err) = await hiveStorage.getValue(StorageKeys.networkFees);
    if (err != null) {
      return;
    }

    final networkFees = NetworkFeesState.fromJson(jsonDecode(result!) as Map<String, dynamic>);
    emit(networkFees);
    await Future.delayed(const Duration(milliseconds: 50));
  }
}
