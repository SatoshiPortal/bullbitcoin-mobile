import 'package:bb_mobile/_pkg/nostr/nostr.dart';
import 'package:bb_mobile/_pkg/storage/hive.dart';
import 'package:bb_mobile/_ui/app_bar.dart';
import 'package:bb_mobile/locator.dart';
import 'package:bb_mobile/nostr/actions_buttons.dart';
import 'package:bb_mobile/nostr/social/social_cubit.dart';
import 'package:bb_mobile/nostr/social/social_state.dart';
import 'package:bb_mobile/nostr/tweet_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:nostr/nostr.dart';

class SocialPage extends StatelessWidget {
  const SocialPage({super.key, required this.nostr});
  final Nostr nostr;

  @override
  Widget build(BuildContext context) {
    return BlocProvider<SocialCubit>(
      create: (_) => SocialCubit(
        nostr: nostr,
        hiveStorage: locator<HiveStorage>(),
      )..subscribe(),
      child: BlocListener<SocialCubit, SocialState>(
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
            final events = List<Event>.from(state.events);
            events.sort((a, b) => b.createdAt.compareTo(a.createdAt));

            return Scaffold(
              backgroundColor: Colors.black,
              appBar: AppBar(
                automaticallyImplyLeading: false,
                flexibleSpace: BBAppBar(
                  text: 'Social',
                  onBack: () => context.pop(),
                ),
              ),
              body: Column(
                children: [
                  Text(
                    'feed: ${state.cached}/${events.length}',
                    style: const TextStyle(color: Colors.red),
                  ),
                  Expanded(
                    child: ListView.builder(
                      itemCount: events.length,
                      itemBuilder: (context, index) {
                        final author = events[index].pubkey;
                        final timestamp = events[index].createdAt;
                        final content = events[index].content;
                        return TweetWidget(
                          pubkey: author,
                          timestamp: timestamp,
                          text: content,
                        );
                        // }
                      },
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            initialValue: state.message,
                            decoration: const InputDecoration(
                              border: OutlineInputBorder(),
                              labelText: 'Message',
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
                      ],
                    ),
                  ),
                ],
              ),
              floatingActionButtonLocation:
                  FloatingActionButtonLocation.endFloat,
              floatingActionButton: ActionsButtons(nostr: nostr),
            );
          },
        ),
      ),
    );
  }
}
