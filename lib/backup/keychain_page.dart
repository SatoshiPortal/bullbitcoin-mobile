import 'package:bb_mobile/_ui/app_bar.dart';
import 'package:bb_mobile/_ui/toast.dart';
import 'package:bb_mobile/backup/bloc/keychain_cubit.dart';
import 'package:bb_mobile/backup/bloc/keychain_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

class KeychainBackupPage extends StatelessWidget {
  const KeychainBackupPage({
    super.key,
    required this.backupKey,
    required this.backupId,
  });

  final String backupKey;
  final String backupId;

  @override
  Widget build(BuildContext context) {
    return BlocProvider<KeychainCubit>(
      create: (_) => KeychainCubit(),
      child: Scaffold(
        backgroundColor: Colors.amber,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          flexibleSpace: BBAppBar(
            text: 'Keychain Backup',
            onBack: () => context.pop(),
          ),
        ),
        body: BlocBuilder<KeychainCubit, KeychainState>(
          builder: (context, state) {
            final cubit = context.read<KeychainCubit>();
            return Column(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Column(
                  children: [
                    SelectableText('Backup Key: $backupKey'),
                    SelectableText('Backup ID: $backupId'),
                  ],
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    SizedBox(
                      width: 100,
                      child: TextFormField(
                        decoration:
                            const InputDecoration(labelText: 'Enter PIN'),
                        keyboardType: TextInputType.number,
                        maxLength: 6,
                        onChanged: (value) => cubit.updateSecret(value),
                      ),
                    ),
                    SizedBox(
                      width: 100,
                      child: TextFormField(
                        decoration:
                            const InputDecoration(labelText: 'Confirm PIN'),
                        keyboardType: TextInputType.number,
                        obscureText: true,
                        maxLength: 6,
                        onChanged: (value) => cubit.confirmSecret(value),
                      ),
                    ),
                  ],
                ),
                if (state.secretConfirmed)
                  ElevatedButton(
                    onPressed: () async {
                      final err = await cubit.secureBackupKey(
                        backupId,
                        backupKey,
                      );
                      final message = err?.message ?? 'Key secured';

                      ScaffoldMessenger.of(context).showSnackBar(
                        context.showToast(message),
                      );
                    },
                    child: const Text('Secure my backup key'),
                  ),
                if (!state.secretConfirmed)
                  const Text(
                    'PINs do not match! Please confirm your PIN.',
                    style: TextStyle(color: Colors.red),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}
