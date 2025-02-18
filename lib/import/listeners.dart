import 'package:bb_mobile/home/bloc/home_bloc.dart';
import 'package:bb_mobile/home/bloc/home_event.dart';
import 'package:bb_mobile/import/hardware_import_bloc/hardware_import_cubit.dart';
import 'package:bb_mobile/import/hardware_import_bloc/hardware_import_state.dart';
import 'package:bb_mobile/locator_old.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

class HardwareImportListeners extends StatelessWidget {
  const HardwareImportListeners({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return MultiBlocListener(
      listeners: [
        BlocListener<HardwareImportCubit, HardwareImportState>(
          listenWhen: (previous, current) =>
              previous.savedWallet != current.savedWallet &&
              current.savedWallet,
          listener: (context, state) {
            locator<HomeBloc>().add(LoadWalletsFromStorage());
            context.go('/home');
          },
        ),
      ],
      child: child,
    );
  }
}
