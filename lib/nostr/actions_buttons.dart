import 'package:bb_mobile/_pkg/nostr/cache.dart';
import 'package:bb_mobile/_pkg/nostr/nostr.dart';
import 'package:flutter/material.dart';
import 'package:flutter_speed_dial/flutter_speed_dial.dart';
import 'package:go_router/go_router.dart';

class ActionsButtons extends StatelessWidget {
  const ActionsButtons({super.key, required this.nostr});
  final Nostr nostr;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 60),
      child: SpeedDial(
        animatedIcon: AnimatedIcons.menu_close,
        backgroundColor: Colors.purpleAccent,
        overlayColor: Colors.black,
        overlayOpacity: 0.5,
        children: [
          SpeedDialChild(
            child: const Icon(Icons.message_rounded),
            label: 'Whispers',
            onTap: () => context.push('/nostr-whispers', extra: nostr),
          ),
          SpeedDialChild(
            child: const Icon(Icons.message_rounded),
            label: 'Clear',
            onTap: Cache.clear,
          ),
        ],
      ),
    );
  }
}
