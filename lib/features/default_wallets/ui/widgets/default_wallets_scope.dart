import 'package:bb_mobile/features/default_wallets/presentation/default_wallets_cubit.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

final class DefaultWalletsScope extends StatefulWidget {
  final DefaultWalletsCubit Function() createCubit;
  final Widget child;

  const DefaultWalletsScope({
    required this.createCubit,
    required this.child,
    super.key,
  });

  @override
  State<DefaultWalletsScope> createState() => _DefaultWalletsScopeState();
}

final class _DefaultWalletsScopeState extends State<DefaultWalletsScope> {
  late final DefaultWalletsCubit _cubit;

  @override
  void initState() {
    super.initState();
    _cubit = widget.createCubit()..init();
  }

  @override
  void dispose() {
    _cubit.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      BlocProvider.value(value: _cubit, child: widget.child);
}
