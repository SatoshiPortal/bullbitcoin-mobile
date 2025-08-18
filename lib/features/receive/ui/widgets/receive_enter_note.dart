import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/note_validator.dart';
import 'package:bb_mobile/core/widgets/buttons/button.dart';
import 'package:bb_mobile/core/widgets/inputs/text_input.dart';
import 'package:bb_mobile/core/widgets/text/text.dart';
import 'package:bb_mobile/features/receive/presentation/bloc/receive_bloc.dart';
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
      constraints: const BoxConstraints(maxWidth: double.infinity),
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
    final currentNote = context.select((ReceiveBloc bloc) => bloc.state.note);
    final error = context.select((ReceiveBloc bloc) => bloc.state.error);

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
            value: currentNote,
            maxLength: NoteValidator.maxNoteLength,
            onChanged: (note) {
              context.read<ReceiveBloc>().add(ReceiveNoteChanged(note));
            },
          ),
          if (error != null) ...[
            const Gap(8),
            BBText(
              error.toString(),
              style: context.font.labelSmall?.copyWith(
                color: context.colour.error,
              ),
            ),
          ],
          const Gap(25),
          const SizedBox(height: 16),
          BBButton.big(
            label: 'Save',
            disabled: error != null || currentNote.trim().isEmpty,
            onPressed: () {
              final validation = NoteValidator.validate(currentNote);
              if (validation.isValid) {
                context.read<ReceiveBloc>().add(const ReceiveNoteSaved());
                context.pop();
              }
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
