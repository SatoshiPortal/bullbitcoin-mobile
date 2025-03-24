import 'package:bb_mobile/_ui/components/loading/progress_screen.dart';
import 'package:bb_mobile/_ui/components/template/screen_template.dart'
    show StackedPage;
import 'package:bb_mobile/key_server/presentation/bloc/key_server_cubit.dart';
import 'package:bb_mobile/key_server/ui/screens/confirm_screen.dart';
import 'package:bb_mobile/key_server/ui/screens/enter_screen.dart';
import 'package:bb_mobile/key_server/ui/screens/recovery_screen.dart';
import 'package:bb_mobile/locator.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart'
    show BlocBuilder, BlocListener, BlocProvider, ReadContext;

class KeyLoadingScreen extends StatelessWidget {
  const KeyLoadingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const ProgressScreen(
      description: 'This will only take a few seconds',
    );
  }
}

class KeySuccessScreen extends StatelessWidget {
  const KeySuccessScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ProgressScreen(
      description:
          'Now let’s test your backup to make sure everything was done properly.',
      title: 'Backup completed!',
      isLoading: false,
      buttonText: 'Test Backup',
      onTap: () => context.read<KeyServerCubit>().updateKeyServerState(
            flow: CurrentKeyServerFlow.recovery,
          ),
    );
  }
}

class KeyServerFlow extends StatelessWidget {
  const KeyServerFlow({super.key, this.encrypted});
  final String? encrypted;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) =>
          locator<KeyServerCubit>()..updateKeyServerState(encrypted: encrypted),
      child: BlocBuilder<KeyServerCubit, KeyServerState>(
        builder: (context, state) {
          if (state.status == const KeyServerOperationStatus.loading()) {
            return const KeyLoadingScreen();
          }

          if (state.status == const KeyServerOperationStatus.success() &&
              state.secretStatus == SecretStatus.stored) {
            return const KeySuccessScreen();
          }

          return switch (state.currentFlow) {
            CurrentKeyServerFlow.enter => const EnterScreen(),
            CurrentKeyServerFlow.confirm => const ConfirmScreen(),
            CurrentKeyServerFlow.recovery => const RecoverScreen(),
            CurrentKeyServerFlow.delete => const EnterScreen(),
          };
        },
      ),
    );
  }
}

class PageLayout extends StatelessWidget {
  const PageLayout({
    required this.bottomChild,
    required this.children,
    this.bottomHeight,
  });

  final Widget bottomChild;
  final List<Widget> children;
  final double? bottomHeight;

  @override
  Widget build(BuildContext context) {
    return StackedPage(
      bottomChildHeight:
          bottomHeight ?? MediaQuery.of(context).size.height * 0.11,
      bottomChild: bottomChild,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: children,
        ),
      ),
    );
  }
}
