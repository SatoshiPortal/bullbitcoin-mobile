import 'package:bb_mobile/_ui/app_bar.dart';
import 'package:bb_mobile/_ui/components/text.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

class MarketHome extends StatelessWidget {
  const MarketHome({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        flexibleSpace: BBAppBar(
          text: 'Market',
          onBack: () {
            context.pop();
          },
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Gap(2),
                Image.asset(
                  'assets/textlogo.png',
                  height: 27,
                  width: 147,
                ),
              ],
            ),
            const BBText.headline(
              'MARKET',
              isBold: true,
            ),
            const Gap(40),
            const BBText.title(
              'COMING SOON',
              isBold: true,
            ),
          ],
        ),
      ),
    );
  }
}


// class MarketHome extends StatelessWidget {
//   const MarketHome({
//     super.key,
//   });

//   @override
//   Widget build(BuildContext context) {
//     return Container(
//       width: double.infinity,
//       height: double.infinity,
//       color: context.colour.onBackground,
//       child: CenterLeft(
//         child: Padding(
//           padding: const EdgeInsets.all(16.0),
//           child: const BBText.headline(
//             'BITCOIN\nEXCHANGE\nCOMING\nSOON!',
//             onSurface: true,
//           ).animate(delay: const Duration(milliseconds: 400)).fadeIn(),
//         ),
//       ),
//     );
//   }
// }
