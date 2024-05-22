import 'package:bb_mobile/network/bloc/network_cubit.dart';
import 'package:bb_mobile/network/bloc/state.dart';
import 'package:bb_mobile/network/popup.dart';
import 'package:bb_mobile/routes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class NetworkListeners extends StatelessWidget {
  const NetworkListeners({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return MultiBlocListener(
      listeners: [
        BlocListener<NetworkCubit, NetworkState>(
          listenWhen: (previous, current) =>
              previous.goToSettings != current.goToSettings &&
              current.goToSettings,
          listener: (context, state) async {
            NetworkPopup.openPopUp(navigatorKey.currentContext!);
          },
        ),
      ],
      child: child,
    );
  }
}
