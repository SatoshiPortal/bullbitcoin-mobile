import 'package:bb_mobile/_pkg/nostr/nostr.dart';
import 'package:bb_mobile/_ui/app_bar.dart';
import 'package:bb_mobile/nostr/tweet_widget.dart';
import 'package:bb_mobile/nostr/whispers/cubit.dart';
import 'package:bb_mobile/nostr/whispers/state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_speed_dial/flutter_speed_dial.dart';
import 'package:go_router/go_router.dart';
import 'package:nostr_sdk/nostr_sdk.dart';

class WhispersPage extends StatelessWidget {
  const WhispersPage({super.key, required this.nostr});
  final Nostr nostr;

  @override
  Widget build(BuildContext context) {
    return BlocProvider<WhispersCubit>(
      create: (_) => WhispersCubit(nostr: nostr)..subscribe(),
      child: BlocListener<WhispersCubit, WhispersState>(
        listener: (context, state) {
          // if (state.toast.isNotEmpty) {
          //   ScaffoldMessenger.of(context).showSnackBar(
          //     SnackBar(
          //       content: Text(state.toast),
          //       backgroundColor: Colors.red,
          //     ),
          //   );
          //   context.read<WhispersCubit>().clearToast();
          // }
        },
        child: BlocBuilder<WhispersCubit, WhispersState>(
          builder: (context, state) {
            final privateEvents =
                Map<String, List<UnsignedEvent>>.from(nostr.privateEventsTmp);

            return Scaffold(
              backgroundColor: Colors.black,
              appBar: AppBar(
                automaticallyImplyLeading: false,
                flexibleSpace: BBAppBar(
                  text: 'Whispers',
                  onBack: () => context.pop(),
                ),
              ),
              body: ListView.builder(
                itemCount: privateEvents.keys.length,
                itemBuilder: (context, index) {
                  final author = privateEvents.keys.elementAt(index);
                  final lastMsg = privateEvents[author]!.last.content();

                  return ListTile(
                    leading: ClipOval(
                      child: Container(
                        width: 50,
                        height: 50,
                        color: generateColor(author),
                        child: Image.network(
                          'https://robohash.org/$author.png',
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                        ),
                      ),
                    ),
                    title: Text(lastMsg),
                    onTap: () => context
                        .push('/nostr-private-message', extra: (nostr, author)),
                  );
                },
              ),
              floatingActionButton: FloatingActionButton(
                onPressed: () => context.push(
                  '/nostr-private-message',
                  extra: (nostr, null),
                ),
                child: const Icon(Icons.add),
              ),
            );
          },
        ),
      ),
    );
  }
}
