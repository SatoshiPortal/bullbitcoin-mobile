import 'package:flutter/material.dart';

class HomeBottomButtons extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const Align(
      alignment: Alignment.bottomCenter,
      child: SizedBox(
        height: 128,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: null,
                        child: Text('Receive'),
                      ),
                    ),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: null,
                        child: Text('Send'),
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    Expanded(
                      child:
                          ElevatedButton(onPressed: null, child: Text('Buy')),
                    ),
                    Expanded(
                      child:
                          ElevatedButton(onPressed: null, child: Text('Sell')),
                    ),
                  ],
                ),
              ],
            ),
            ElevatedButton(
              onPressed: null,
              child: Icon(Icons.qr_code_scanner),
            ),
          ],
        ),
      ),
    );
  }
}
