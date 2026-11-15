import 'package:bb_mobile/features/address_view/presentation/address_explorer_cubit.dart';
import 'package:bb_mobile/features/address_view/public/address_explorer_route.dart';
import 'package:bb_mobile/features/address_view/ui/screens/address_explorer_screen.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';

class AddressExplorerRouter {
  static final route = GoRoute(
    name: AddressExplorerRoute.addressExplorer.name,
    path: AddressExplorerRoute.addressExplorer.path,
    builder: (context, state) {
      final args = state.extra;
      if (args is! AddressExplorerArgs) {
        return const AddressExplorerUnavailableScreen();
      }
      return BlocProvider(
        create: (_) => GetIt.I<AddressExplorerCubit>(param1: args)..load(),
        child: const AddressExplorerScreen(),
      );
    },
  );
}
