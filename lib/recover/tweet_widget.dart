import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:oktoast/oktoast.dart';

class TweetWidget extends StatelessWidget {
  const TweetWidget({
    super.key,
    required this.pubkey,
    required this.timestamp,
    required this.text,
  });

  final String pubkey;
  final int timestamp;
  final String text;

  String formatDate(int secondsUnixTimestamp) {
    final date = DateTime.fromMillisecondsSinceEpoch(
      secondsUnixTimestamp * 1000,
      isUtc: true,
    ).toLocal();
    return "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}";
  }

  Color generateColor() {
    final hexColor = pubkey.substring(0, 6).padRight(6, '0');
    return Color(int.parse('0xFF$hexColor'));
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(5.0),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(15),
          color: Colors.black,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 5),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipOval(
                child: Container(
                  width: 46,
                  height: 46,
                  color: generateColor(),
                  child: Image.network(
                    'https://robohash.org/$pubkey.png',
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        GestureDetector(
                          onTap: () {
                            Clipboard.setData(ClipboardData(text: pubkey));
                            showToast('Copied to clipboard: $pubkey');
                          },
                          child: Text(
                            pubkey.substring(0, 8),
                            style: const TextStyle(color: Colors.white),
                          ),
                        ),
                        Text(
                          formatDate(timestamp),
                          style: const TextStyle(color: Colors.white70),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    SelectableText(
                      text,
                      style: const TextStyle(color: Colors.white),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
