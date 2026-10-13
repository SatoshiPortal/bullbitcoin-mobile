import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/widgets/backup_success_screen.dart';
import 'package:bb_mobile/features/recoverbull/presentation/bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

class TestCompletedPage extends StatelessWidget {
  const TestCompletedPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BackupSuccessScreen(
      title: context.loc.recoverbullTestCompletedTitle,
      message: context.loc.recoverbullTestSuccessDescription,
      buttonLabel: context.loc.recoverbullGotIt,
      onDone: context.read<RecoverBullBloc>().state.returnToCaller
          ? () => context.pop(true)
          : null,
    );
  }
}
