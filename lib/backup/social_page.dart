import 'package:bb_mobile/_pkg/file_storage.dart';
import 'package:bb_mobile/_ui/app_bar.dart';
import 'package:bb_mobile/backup/bloc/social_cubit.dart';
import 'package:bb_mobile/backup/bloc/social_setting_state.dart';
import 'package:bb_mobile/backup/bloc/social_state.dart';
import 'package:bb_mobile/backup/tweet_widget.dart';
import 'package:bb_mobile/locator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

class SocialPage extends StatelessWidget {
  const SocialPage({super.key, required this.settings});
  final SocialSettingState settings;

  @override
  Widget build(BuildContext context) {
    final message = TextEditingController();

    return BlocProvider<SocialCubit>(
      create: (_) => SocialCubit(
        fileStorage: locator<FileStorage>(),
        relay: settings.relay,
        senderSecret: settings.secretKey,
        senderPublic: settings.publicKey,
        friendPublic: settings.receiverPublicKey,
        backupKey: settings.backupKey,
      ),
      child: Scaffold(
        backgroundColor: Colors.amber,
        appBar: AppBar(
          automaticallyImplyLeading: false,
          flexibleSpace: BBAppBar(
            text: 'Social',
            onBack: () => context.pop(),
          ),
        ),
        body: BlocListener<SocialCubit, SocialState>(
          listener: (context, state) {
            if (state.toast.isNotEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(state.toast),
                  backgroundColor: Colors.red,
                ),
              );
              context.read<SocialCubit>().clearToast();
            }
          },
          child: BlocBuilder<SocialCubit, SocialState>(
            builder: (context, state) {
              final cubit = context.read<SocialCubit>();

              return Column(
                children: [
                  Expanded(
                    child: ListView.builder(
                      itemCount: state.messages.length,
                      itemBuilder: (context, index) {
                        final pubkey = state.messages[index].pubkey;
                        final timestamp = state.messages[index].createdAt;
                        final content = state.messages[index].content;
                        final id = state.messages[index].id;

                        if (state.filter.containsKey(id)) {
                          final fake = state.filter[id]!;
                          return TweetWidget(
                            pubkey: fake.pubkey,
                            timestamp: fake.createdAt,
                            text: fake.content,
                          );
                        } else {
                          return TweetWidget(
                            pubkey: pubkey,
                            timestamp: timestamp,
                            text: content,
                          );
                        }
                      },
                    ),
                  ),
                  Row(
                    children: [
                      ElevatedButton.icon(
                        icon: const Icon(Icons.backup),
                        label: const Text('Request Backup'),
                        onPressed: () async => await cubit.backupRequest(),
                      ),
                      if (state.friendBackupKey.isNotEmpty)
                        ElevatedButton.icon(
                          icon: const Icon(Icons.cloud_download),
                          label: const Text('Download Backup Key'),
                          onPressed: () async => cubit.backupConfirm(),
                        ),
                    ],
                  ),
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: message,
                            decoration: const InputDecoration(
                              border: OutlineInputBorder(),
                              labelText: 'Write Message',
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.send),
                          onPressed: () async {
                            await cubit.sendPM(message.text);
                            message.clear();
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
