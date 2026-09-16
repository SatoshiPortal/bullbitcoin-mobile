# Reproduire les vérifications

Exécution depuis `/home/nicolas/Cage/repos/BULL`, avec le SDK FVM du dépôt. Ces fichiers utilisent uniquement des fixtures publiques. Les sondes restent hors du dépôt.

## Environnement de cet audit

```bash
export PATH=/home/nicolas/fvm/bin:/home/nicolas/.cargo/bin:$PATH
export LD_LIBRARY_PATH=/tmp/secrets-release-audit-20260915/native-libs:${LD_LIBRARY_PATH:-}
```

Le répertoire temporaire contient des liens vers `libsqlite3.so.0` installé et `librust_lib_bull_sdk.so` déjà compilé dans le build Linux du dépôt. Un autre hôte doit fournir ses propres bibliothèques correspondant au lockfile ; ces liens ne sont pas des dépendances à commiter.

## Vérifications canoniques

```bash
make analyze
make fix-check
make format-check
make bull-ui-check
make unit-test
```

Le make des tests s’arrête si la suite app échoue, avant de visiter les packages. Le lancement indépendant effectué pour `secrets` reprend sa commande exacte :

```bash
cd /home/nicolas/Cage/repos/BULL/packages/secrets
fvm flutter test --reporter=compact
```

## Sondes sur l’état final audité

Depuis la racine du dépôt :

```bash
fvm flutter test /tmp/secrets-release-audit-20260915/signature_probes_test.dart --reporter=expanded
fvm flutter test /tmp/secrets-release-audit-20260915/native_derivation_probes_test.dart --reporter=expanded
fvm flutter test /tmp/secrets-release-audit-20260915/widget_final_checks_test.dart --reporter=expanded
fvm flutter test /tmp/secrets-release-audit-20260915/boundary_final_checks_test.dart --reporter=expanded
fvm flutter test /tmp/secrets-release-audit-20260915/import_race_probe_test.dart --reporter=expanded
fvm flutter test /tmp/secrets-release-audit-20260915/invariant_mutation_probe_test.dart --reporter=expanded
```

Les sondes de défaut attendent volontairement le comportement problématique : signature après suppression, restauration sans passphrase, nettoyage concurrent destructif, invariant aveugle. Leur succès **confirme le constat**. Pour devenir un test d’acceptation, leur attente doit être inversée ou adaptée au contrat corrigé.

## États historiques conservés

- `boundary_probes_test.dart` attend l’ancien retry qui absorbait un `StateError` ; il ne doit plus passer après sa correction. Utiliser `boundary_final_checks_test.dart` pour l’état final.
- `mnemonic_view_probe_test.dart` importe le widget de la copie initiale immuable pour reproduire les mots périmés ; `widget_final_checks_test.dart` vérifie le widget corrigé du dépôt.
- `bip85_path_probe_test.dart` attend l’ancienne réinterprétation silencieuse ; elle ne doit plus passer après le correctif. Les quatre régressions de Claude sont désormais dans `test/core_test/bip85/derive_next_bip85_usecase_test.dart`.
- `invariant_mutation_probe_test.dart` compile une copie modifiée sous `/tmp/secrets-release-audit-20260915/mutated-invariant-copy`. Son chemin exact est dans le fichier. Il ne modifie jamais les sources du dépôt.

Les logs sont datés par leurs événements et référencés dans `RAPPORT_RELEASE.md`. Les premières erreurs de montage des sondes restent conservées pour la traçabilité ; elles ne sont pas comptées comme défauts du package.
