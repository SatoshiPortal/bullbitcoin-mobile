import 'package:bb_mobile/receive/presentation/bloc/receive_bloc.dart';
import 'package:bb_mobile/router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

class ReceiveScaffold extends StatelessWidget {
  final Widget body;

  const ReceiveScaffold({super.key, required this.body});

  @override
  Widget build(BuildContext context) {
    final hasReceived =
        context.select((ReceiveBloc bloc) => bloc.state.hasReceived);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Receive bitcoin'),
        actions: !hasReceived
            ? null
            : [
                CloseButton(
                  onPressed: () => context.goNamed(AppRoute.home.name),
                ),
              ],
      ),
      body: body,
    );
  }
}
