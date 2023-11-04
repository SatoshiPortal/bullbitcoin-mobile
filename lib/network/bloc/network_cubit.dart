import 'dart:convert';

import 'package:bb_mobile/_pkg/storage/hive.dart';
import 'package:bb_mobile/_pkg/storage/storage.dart';
import 'package:bb_mobile/network/bloc/state.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class NetworkCubit extends Cubit<NetworkState> {
  NetworkCubit({required this.hiveStorage}) : super(const NetworkState()) {
    init();
  }

  final HiveStorage hiveStorage;

  @override
  void onChange(Change<NetworkState> change) {
    super.onChange(change);
    hiveStorage.saveValue(
      key: StorageKeys.network,
      value: jsonEncode(change.nextState.toJson()),
    );
  }

  Future<void> init() async {
    Future.delayed(const Duration(milliseconds: 200));
    final (result, err) = await hiveStorage.getValue(StorageKeys.network);
    if (err != null) {
      return;
    }

    final network = NetworkState.fromJson(jsonDecode(result!) as Map<String, dynamic>);
    emit(network);
    await Future.delayed(const Duration(milliseconds: 50));
  }
}
