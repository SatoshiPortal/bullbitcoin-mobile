import 'package:bb_mobile/features/receive/presentation/bloc/receive_bloc.dart';
import 'package:bb_mobile/ui/components/buttons/button.dart';
import 'package:bb_mobile/ui/components/inputs/text_input.dart';
import 'package:bb_mobile/ui/components/text/text.dart';
import 'package:bb_mobile/ui/themes/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

class ReceiveEnterNote extends StatelessWidget {
  const ReceiveEnterNote({super.key});

  static Future showBottomSheet(BuildContext context) async {
    final receive = context.read<ReceiveBloc>();

    await showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      backgroundColor: context.colour.onPrimary,
      isScrollControlled: true,
      builder: (context) {
        return BlocProvider.value(
          value: receive,
          child: const ReceiveEnterNote(),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        0,
        16,
        MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Gap(22),
          Row(
            children: [
              const Gap(22),
              const Spacer(),
              BBText('Add Label', style: context.font.headlineMedium),
              const Spacer(),
              IconButton(
                onPressed: () {
                  context.pop();
                },
                color: context.colour.secondary,
                icon: const Icon(Icons.close_sharp),
              ),
            ],
          ),
          const Gap(33),
          BBInputText(
            hint: 'Note',
            hintStyle: context.font.bodyLarge?.copyWith(
              color: context.colour.surfaceContainer,
            ),
            value: context.select((ReceiveBloc bloc) => bloc.state.note),
            onChanged: (note) {
              context.read<ReceiveBloc>().add(ReceiveNoteChanged(note));
            },
          ),
          const Gap(25),
          const SizedBox(height: 16),
          BBButton.big(
            label: 'Save',
            onPressed: () {
              context.read<ReceiveBloc>().add(const ReceiveNoteSaved());
              context.pop();
            },
            bgColor: context.colour.secondary,
            textColor: context.colour.onSecondary,
          ),
          const Gap(24),
        ],
      ),
    );
  }
}
