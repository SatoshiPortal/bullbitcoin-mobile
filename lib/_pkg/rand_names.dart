import 'dart:math';

class RandomName {
  String create() {
    final adjective = ['Stealthy', 'Groovy', 'Radical', 'Neat', 'Modern', 'Dignified', 'Hopeful'];
    final nouns = ['Bull', 'Stack', 'Mate', 'Wolf', 'Ape', 'Whale', 'Soldier', 'Beans'];

    final random = Random();
    final randAdj = adjective[random.nextInt(adjective.length)];
    final randNoun = nouns[random.nextInt(nouns.length)];
    return randAdj + ' ' + randNoun;
  }

  String getUnique(List<String> existingNames) {
    final name = RandomName().create();
    if (existingNames.contains(name)) {
      return getUnique(existingNames);
    } else {
      return name;
    }
  }
}
