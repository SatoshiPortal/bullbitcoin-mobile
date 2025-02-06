import 'package:bb_mobile/_pkg/nostr/nostr.dart';
import 'package:bb_mobile/_ui/app_bar.dart';
import 'package:bb_mobile/nostr/private_message/cubit.dart';
import 'package:bb_mobile/nostr/private_message/state.dart';
import 'package:bb_mobile/nostr/tweet_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:nostr/nostr.dart';

class PrivateMessagePage extends StatelessWidget {
  const PrivateMessagePage({super.key, required this.nostr, this.contact});
  final Nostr nostr;
  final String? contact;

  @override
  Widget build(BuildContext context) {
    return BlocProvider<PrivateMessageCubit>(
      create: (_) => PrivateMessageCubit(
        nostr: nostr,
        contact: contact,
      )..subscribe(),
      child: BlocListener<PrivateMessageCubit, PrivateMessageState>(
        listener: (context, state) {
          // if (state.toast.isNotEmpty) {
          //   ScaffoldMessenger.of(context).showSnackBar(
          //     SnackBar(
          //       content: Text(state.toast),
          //       backgroundColor: Colors.red,
          //     ),
          //   );
          //   context.read<PrivateMessageCubit>().clearToast();
          // }
        },
        child: BlocBuilder<PrivateMessageCubit, PrivateMessageState>(
          builder: (context, state) {
            final cubit = context.read<PrivateMessageCubit>();

            final privateEvents = nostr.privateEventsTmp;

            final history = <Event>[];
            if (state.contact.isNotEmpty &&
                privateEvents.containsKey(state.contact)) {
              history.addAll(List.from(privateEvents[state.contact]!));
              history.sort((a, b) => b.createdAt.compareTo(a.createdAt));
            }

            return Scaffold(
              backgroundColor: Colors.black,
              appBar: AppBar(
                automaticallyImplyLeading: false,
                flexibleSpace: BBAppBar(
                  text: 'Private Message',
                  onBack: () => context.pop(),
                ),
              ),
              body: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  children: [
                    TextFormField(
                      initialValue: state.contact,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        labelText: 'Contact',
                        fillColor: Colors.white,
                      ),
                      cursorColor: Colors.white,
                      style: const TextStyle(color: Colors.white),
                      onChanged: cubit.updateContact,
                    ),
                    Expanded(
                      child: ListView.builder(
                        itemCount: history.length,
                        itemBuilder: (context, index) {
                          final author = history[index].pubkey;
                          final timestamp = history[index].createdAt;
                          final content = history[index].content;

                          return TweetWidget(
                            pubkey: author,
                            timestamp: timestamp,
                            text: content,
                          );
                          // }
                        },
                      ),
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            initialValue: state.message,
                            decoration: const InputDecoration(
                              border: OutlineInputBorder(),
                              labelText: 'Private Message',
                              fillColor: Colors.white,
                            ),
                            cursorColor: Colors.white,
                            style: const TextStyle(color: Colors.white),
                            onChanged: cubit.updateMessage,
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.send),
                          onPressed: cubit.clickOnSend,
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.send_and_archive),
                          onPressed: cubit.clickOnSend,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
