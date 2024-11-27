import 'package:bb_mobile/_pkg/file_picker.dart';
import 'package:bb_mobile/_ui/app_bar.dart';
import 'package:bb_mobile/_ui/components/button.dart';
import 'package:bb_mobile/locator.dart';
import 'package:bb_mobile/recover/bloc/keychain_cubit.dart';
import 'package:bb_mobile/recover/bloc/keychain_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

class KeychainRecoverPage extends StatelessWidget {
  const KeychainRecoverPage({super.key, required this.backupId});

  final String backupId;

  @override
  Widget build(BuildContext context) {
    return BlocProvider<KeychainCubit>(
      create: (_) => KeychainCubit(filePicker: locator<FilePick>()),
      child: Scaffold(
        backgroundColor: Colors.amber,
        appBar: AppBar(
          automaticallyImplyLeading: false,
          flexibleSpace: BBAppBar(
            text: 'Recover Backup',
            onBack: () => context.pop(),
          ),
        ),
        body: BlocListener<KeychainCubit, KeychainState>(
          listener: (context, state) {
            if (state.error.isNotEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(state.error),
                  backgroundColor: Colors.red,
                ),
              );
              context.read<KeychainCubit>().clearError();
            }
            if (state.backupKey.isNotEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Backup Key recovered'),
                  backgroundColor: Colors.green,
                ),
              );
            }
          },
          child: BlocBuilder<KeychainCubit, KeychainState>(
            builder: (context, state) {
              final cubit = context.read<KeychainCubit>();

              final backupKey = state.backupKey;
              final secret = state.secret;

              return Column(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  if (backupKey.isEmpty && backupId.isNotEmpty)
                    Center(
                      child: SizedBox(
                        width: 100,
                        child: TextFormField(
                          decoration:
                              const InputDecoration(labelText: 'Enter PIN'),
                          keyboardType: TextInputType.number,
                          maxLength: 6,
                          onChanged: (value) => cubit.updateSecret(value),
                        ),
                      ),
                    ),
                  if (backupKey.isEmpty &&
                      backupId.isNotEmpty &&
                      secret.length == 6)
                    BBButton.big(
                      label: 'Recover Backup Key',
                      center: true,
                      onPressed: () => cubit.clickRecoverKey(),
                    ),
                  if (backupKey.isNotEmpty) SelectableText(backupKey),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
