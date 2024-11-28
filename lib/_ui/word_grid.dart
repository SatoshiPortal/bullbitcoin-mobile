import 'package:bb_mobile/_ui/components/text.dart';
import 'package:flutter/material.dart';

class WordGrid extends StatelessWidget {
  const WordGrid({super.key, required this.mne});

  final List<String> mne;

  static List<Widget> reorderWidgets(List<Widget> mne) {
    final List<Widget> list = [];
    list.add(mne[0]);
    list.add(mne[4]);
    list.add(mne[8]);
    list.add(mne[1]);
    list.add(mne[5]);
    list.add(mne[9]);
    list.add(mne[2]);
    list.add(mne[6]);
    list.add(mne[10]);
    list.add(mne[3]);
    list.add(mne[7]);
    list.add(mne[11]);
    return list;
  }

  static List<Widget> reorderWidgets24(List<Widget> mne) {
    final List<Widget> list = [];
    list.add(mne[0]);
    list.add(mne[8]);
    list.add(mne[16]);
    list.add(mne[1]);
    list.add(mne[9]);
    list.add(mne[17]);
    list.add(mne[2]);
    list.add(mne[10]);
    list.add(mne[18]);
    list.add(mne[3]);
    list.add(mne[11]);
    list.add(mne[19]);
    list.add(mne[4]);
    list.add(mne[12]);
    list.add(mne[20]);
    list.add(mne[5]);
    list.add(mne[13]);
    list.add(mne[21]);
    list.add(mne[6]);
    list.add(mne[14]);
    list.add(mne[22]);
    list.add(mne[7]);
    list.add(mne[15]);
    list.add(mne[23]);

    return list;
  }

  @override
  Widget build(BuildContext context) {
    if (mne.isEmpty) return const SizedBox.shrink();
    if (mne.length == 12) {
      return SizedBox(
        height: 200,
        width: double.infinity,
        child: GridView.count(
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 3,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          childAspectRatio: 5 / 1.5,
          children: reorderWidgets([
            for (var i = 0; i < mne.length; i++)
              _Word(
                idx: i,
                word: mne[i],
              ),
          ]),
        ),
      );
    } else {
      return SizedBox(
        height: 300,
        width: double.infinity,
        child: GridView.count(
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 3,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          childAspectRatio: 5 / 1.5,
          children: reorderWidgets24([
            for (var i = 0; i < mne.length; i++)
              _Word(
                idx: i,
                word: mne[i],
              ),
          ]),
        ),
      );
    }
  }
}

class _Word extends StatelessWidget {
  const _Word({required this.idx, required this.word});

  final int idx;
  final String word;

  @override
  Widget build(BuildContext context) {
    return BBText.body(
      '${idx + 1}. $word',
    );
  }
}
