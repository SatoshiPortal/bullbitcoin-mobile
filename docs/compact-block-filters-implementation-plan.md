# Plan d'implementation Compact Block Filters

Precondition : executer et valider le spike de la phase 0. Aucune phase ulterieure ne doit commencer tant que les criteres de sortie de la phase precedente ne sont pas satisfaits.

Le detail de chaque probleme, de sa justification, de sa resolution conceptuelle et de snippets est dans `docs/compact-block-filters-technical-design.md`.

## Principes de produit

- CBF est un choix explicite, desactive par defaut pendant sa phase de lancement.
- L'option doit dire clairement ce qu'elle apporte : synchronisation Bitcoin plus privee, sans envoyer la liste complete des adresses a un serveur Electrum unique pour l'historique confirme.
- L'option doit dire clairement ce qu'elle ne fournit pas : les paiements entrants non confirmes peuvent ne pas apparaitre avant leur premier bloc.
- Le premier scan ne doit pas bloquer silencieusement le parcours wallet. L'utilisateur voit une progression, peut annuler, et peut reprendre ulterieurement grace aux donnees CBF persistantes.
- La V1 est foreground uniquement. Le background n'est pas un critere de lancement et fera l'objet de PRs plateformes ulterieures.
- Les secrets ne doivent jamais etre envoyes aux pairs, a l'API mempool, aux logs ou a l'etat persiste de la progression.

## Perimetre V1 propose

**Inclus** : Bitcoin uniquement, backend par wallet, foreground, progression/annulation, reprise depuis `dataDir`, historique confirme via CBF, broadcast Electrum, frais actuels, connexion CBF clearnet et feature flag opt-in.

**Conditionnel au spike** : insertion locale des envois propres avec `applyUnconfirmedTxs`, RBF/CPFP avant confirmation et Payjoin. Une capacite conditionnelle n'est activee que si son test pass/fail est vert.

**Exclus** : Tor, reception 0-conf globale, full scan Electrum parallele, broadcast P2P CBF, background Android/iOS, migration automatique des wallets existants et activation par defaut.

**Tor est exclu pour une raison structurelle, pas par simplicite** : le pin actuel de `bdk_dart` ne contient pas `only_configured_peers()` (ajoute a bdk-ffi apres notre revision), et sans ce mode le bootstrap DNS de Kyoto se declenche en clair des que les pairs configures echouent, meme avec `socks5Proxy` et une liste non vide. La levee de cette exclusion est definie dans la porte GT ci-dessous.

**Interaction avec le toggle Tor existant** : Bull proxifie deja l'Electrum Bitcoin quand `useTorProxy` est actif. Un wallet CBF V1 contournerait ce proxy silencieusement. La V1 doit donc, quand `useTorProxy` est actif : soit masquer/bloquer le choix CBF avec explication, soit exiger une confirmation explicite "la synchronisation privee n'utilise pas encore Tor ; votre IP sera visible des pairs Bitcoin". Aucun contournement silencieux.

La promesse V1 est precise : "votre wallet verifie localement les filtres sans envoyer ses adresses a un serveur de scan unique". Elle ne doit jamais etre formulee comme "anonyme" ou "cache votre IP".

## Portes de decision

| Porte | Condition go | Consequence si rouge |
|---|---|---|
| G0 Stabilite | Zero crash FFI, corruption, double session ou lock SQLite dans les cycles imposes. | No-go CBF. |
| G1 Confidentialite V1 | Aucun script/adresse du wallet n'est envoye aux pairs pendant le scan ; l'UI indique que l'IP reste visible sans Tor. | No-go CBF si le scan divulgue les scripts ou si la copie produit surpromet l'anonymat. |
| G2 Parite confirmee | Meme tip, transactions, UTXO et solde confirmes que le controle Electrum. | No-go CBF. |
| G3 Envois propres | Insertion, persistence, confirmation, eviction, replacement, RBF et CPFP corrects. | CBF reste beta "confirme uniquement" ou no-go produit si la parite RBF est obligatoire. |
| G4 Payjoin | Verification complete des prevouts, montants et frais avec inputs etrangers. | Payjoin reste Electrum ou est indisponible pour les wallets CBF. |
| G5 Mobile | Shutdown/reprise fiables sur Android et iOS reels ; aucune promesse background. | Plateforme rouge exclue du lancement CBF. |
| GT Tor (post-V1) | Pin `bdk-ffi` >= PR #1047 dans `bull_sdk`, `onlyConfiguredPeers()` + liste IP auditee + `socks5Proxy`, redemarrage gere sur `NoReachablePeers`, et capture reseau prouvant zero DNS/connexion clearnet. | Tor+CBF reste bloque ; le toggle `useTorProxy` continue de bloquer ou d'avertir la selection CBF. |

## Phase 0 : spike technique bloqueur

Objectif : prouver le comportement reel de `bdk_dart` verrouille par Bull, sur appareils Android et iOS, avant toute migration de produit.

1. Construire un harness non production avec un wallet descripteur testnet et un `dataDir` CBF temporaire. Le harness ne modifie ni Drift ni le wizard.
2. Demarrer `CbfNode` une seule fois ; lire concurremment `nextInfo()` et `nextWarning()` ; traiter tous les `Info` (`ConnectionsMetInfo`, `SuccessfulHandshakeInfo`, `ProgressInfo`, `BlockReceivedInfo`) ; attendre `update()`, appliquer l'update et persister le wallet.
3. Verifier `SyncScanType` et les variantes de `RecoveryScanType` avec `GenesisBlockRecoveryPoint`, `SegwitActivationRecoveryPoint`, `TaprootActivationRecoveryPoint` et `OtherRecoveryPoint(BlockId)`. Definir comment Bull obtient un `BlockId` depuis son `birthday: DateTime?`, et comment l'index utilise couvre les keychains externe/interne, avec le cout de confidentialite du lookup eventuel.
4. Mesurer wallet neuf et restaure : temps au premier progres, temps total, octets, espace disque et batterie, separement Wi-Fi et cellulaire. Tor est hors V1.
5. Tester `shutdown()` pendant connexion, telechargement et application d'update, y compris deux annulations concurrentes. Le wrapper doit rendre l'operation idempotente bien que le second appel natif leve `NodeStoppedCbfException`.
6. Executer au moins 20 cycles forces kill/restart pendant `update()`/persistance. Chaque cycle doit se terminer sans crash, sans erreur SQLite et avec le meme tip, solde, transactions et UTXO qu'un wallet de controle Electrum apres confirmation.
7. Executer au moins 20 synchronisations concurrentes Electrum-isolate/CBF-thread sur des wallets distincts : zero double noeud par wallet, zero `database is locked`, zero crash FFI et zero race du provider cryptographique.
8. Tester `Wallet.applyUnconfirmedTxs()` puis persistance pour un envoi propre ; verifier apres redemarrage l'historique pending, le change, RBF et CPFP ; puis verifier reconciliation avec confirmation, replacement et `applyEvictedTxs()`.
9. Tester ajout d'adresse et derivation change pendant une session. Reproduire ou exclure explicitement `bdk-kyoto#143` avant d'autoriser la derivation pendant un scan actif.
10. Tester `bdk-kyoto#136` avec Payjoin : tracer les prevouts et la verification des frais/inputs dans `pdk_payjoin_datasource.dart`. Si tous les prevouts ne peuvent pas etre verifies, Payjoin reste Electrum ou est indisponible pour CBF.
11. Tester `bdk-kyoto#162` pour un wallet neuf et chaque recovery/import supporte. Aucun mode recovery ne doit etre choisi par heuristique non verifiee.
12. Capturer le reseau clearnet pour verifier qu'aucun script, adresse, descripteur ou identifiant wallet n'est transmis aux pairs. Documenter les DNS seeds et pairs contactes, ainsi que le fait que l'IP source reste visible.
13. Tester foreground, ecran verrouille, bascules rapides foreground/background, terminaison du processus, reprise et absence de connectivite sur Android et iOS reels. Le spike ne promet pas de continuation en background.

Sortie attendue : rapport de mesures par plateforme, captures sanitisees des sequences `Info`/`Warning`, tests reproductibles et tableau pass/fail pour chaque critere ci-dessus. Un seul critere de securite ou d'integrite rouge donne no-go ou impose de garder le flux concerne sur Electrum. Le spike n'ajoute aucune option utilisateur persistante.

## Phase 1 : contrat et stockage

Objectif : ajouter le choix de backend sans exposer BDK a la presentation ni casser les wallets existants.

1. Ajouter une preference de synchronisation Bitcoin persistante par wallet : `electrum` ou `compactBlockFilters`, avec version de schema et migration vers `electrum` pour tous les wallets existants.
2. Etendre les structures existantes `WalletMetadatas` et `WalletMetadataModel`; ne pas creer un second concept de metadata. Executer `make drift-migrations` et tester la migration schema 13 vers 14 ainsi que les snapshots historiques supportes.
3. Definir les types domaine publies par le coeur wallet : etat de sync scelle (`idle`, `connecting`, `scanning(percent, chainHeight)`, `degraded`, `completed`, `cancelled`) et famille `WalletSyncFailure` conforme a la convention du depot.
4. Ajouter un contrat **additif** `WalletSyncRepository` qui retourne uniquement ces types domaine et un moyen d'annuler un scan. Il ne migre pas tout `core/wallet` vers `Result` dans la meme PR. Les types `bdk.Info`, `bdk.Warning`, `CbfClient` et les erreurs FFI restent dans la datasource.
5. Implementer une datasource CBF Bitcoin responsable du cycle de vie unique par wallet : construire le wallet, construire le client/noeud, lancer le noeud, lire info/warnings, appliquer les updates, persister le wallet, arreter le noeud et liberer ses ressources.
6. Definir un chemin de stockage non secret et stable par wallet/reseau pour `dataDir`, ainsi que creation, retention, nettoyage lors de la suppression wallet et gestion d'espace disque.
7. Implementer la politique de pairs clearnet validee par le spike. Ne pas brancher `socks5Proxy` en V1 : sans `only_configured_peers` (absent du pin actuel), le DNS clearnet resterait possible et donnerait une fausse garantie. La PR Tor future suit la porte GT.
8. Gerer l'interaction avec `useTorProxy` : bloquer ou faire confirmer explicitement le choix CBF quand le toggle Tor est actif, tant que GT n'est pas verte.

Critere de sortie : tests unitaires de mapping et de cycle de vie, migration testee, aucun wallet existant ne bascule de backend sans consentement, et aucune API BDK ne franchit les limites data/domain/presentation.

Note architecture : `lib/core/wallet/data/repositories/` contient aujourd'hui des repositories concrets sans interface domaine, ce qui contrevient a la regle 6 d'`AGENTS.md`. Cette dette ne doit pas etre copiee. La solution minimale est un nouveau contrat `WalletSyncRepository`, independant du refactoring global. Si le refactoring global est accepte, il reste un commit/PR atomique distinct.

## Phase 2 : choix utilisateur et UX foreground

Objectif : rendre CBF comprehensible, reversible avant le premier sync et observable pendant un scan long.

1. Dans le wizard pre-locator, ajouter un `WizardField` et une valeur dans `WizardChoices`; `ApplyPendingWizardChoicesUsecase` la transfere vers une preference globale `SettingsRepository`. `CreateDefaultWalletsUsecase` consomme cette preference comme il consomme aujourd'hui `environment`. Cette preference n'est qu'un defaut pour les nouveaux wallets.
2. Dans la creation/restauration de wallet, afficher le backend effectivement choisi et une information specifique : "les paiements recus ne seront pas visibles avant leur confirmation", sauf si un futur suivi 0-conf explicite est active. L'utilisateur peut conserver Electrum ou choisir CBF avant le premier scan.
3. Pour une restauration, distinguer l'etape de recherche/recovery de la synchronisation normale. Configurer le scan de recovery selon le birthday/checkpoint applicable ; ne pas masquer un scan historique couteux sous une barre de progression trompeuse.
4. Creer dans `bull_ui` un composant de progression reutilisable, car aucun composant determine n'existe aujourd'hui. Conserver `BullSyncButton` pour l'action et reutiliser le nouveau composant dans au moins le parcours initial et le detail de sync.
5. Afficher au minimum : recherche de pairs, hauteur connue, pourcentage des filtres, avertissement recuperable, dernier progres, annuler, et le fait que le scan reprendra plus tard. Ne pas afficher IP de pair, descripteur ou information de wallet sensible.
6. Une annulation declenche `shutdown()`, est affichee comme annulation et non echec, puis permet "Reprendre". Plusieurs vues ne doivent jamais creer plusieurs noeuds pour le meme wallet.
7. L'etat de progression doit etre conduit par un use case et observe par un bloc/cubit mince. Le bloc ne contacte ni datasource ni facade d'un autre feature.

Les imports sont livres par feature dans des PRs separees apres la creation par defaut : mnemonic, watch-only, hardware/QR et recoveries ne doivent pas etre regroupes dans une seule PR.

Critere de sortie : maquettes validees, traductions ajoutees via l'outil ARB du depot, tests BLoC/UI de tous les etats, et tests manuels desktop/mobile layouts applicables.

### Parcours UX V1

Le parcours doit montrer la confidentialite comme un benefice simple, sans exposer BIP157, Kyoto, peers ou descripteurs dans l'interface principale.

1. **Choix en une action** : une carte "Enhanced Bitcoin privacy" explique en une phrase que Bull recherche les paiements localement au lieu d'envoyer les adresses a un serveur de scan. Un lien secondaire "How it works" explique les limites : IP visible, receptions visibles apres confirmation, foreground requis pendant le scan initial.
2. **Confirmation contextuelle** : avant creation/restauration, un resume affiche "Private sync: On" et permet de revenir a Electrum sans quitter le parcours. Le choix reste opt-in pendant la beta.
3. **Demarrage immediat** : apres creation, l'utilisateur arrive sur un ecran wallet fonctionnel avec une carte de sync persistante, pas sur un ecran bloquant sans navigation. La generation d'adresse locale reste disponible, mais la carte precise que les paiements ne seront detectes qu'une fois le scan a jour.
4. **Progression comprehensible** : afficher un libelle humain (`Connecting`, `Checking Bitcoin history`, `Up to date`), une barre et un pourcentage. La hauteur et les details techniques sont places dans un panneau secondaire, pas dans le message principal.
5. **Interruption honnete** : si l'utilisateur quitte l'app, afficher avant la premiere sortie explicite que le scan se mettra en pause et reprendra au retour. Ne jamais dire "continues in background" en V1.
6. **Reprise sans friction** : au retour, la meme carte reprend automatiquement depuis les donnees persistantes, sans redemander le choix et sans afficher une erreur pour une interruption normale.
7. **Warnings utiles** : traduire les warnings techniques en actions simples : verifier la connexion, reessayer, changer de reseau. Les details BDK restent dans les logs sanitises, jamais dans le message utilisateur.
8. **Fin visible puis discrete** : afficher une confirmation courte "Private sync is up to date", puis reduire la carte en un statut compact accessible depuis le wallet.
9. **Sortie de secours** : en cas d'echec repete, proposer "Use standard sync" avec explication. Le switch preserve le wallet et ne supprime pas silencieusement les donnees CBF.

### Criteres UX mesurables

- Le choix CBF demande au plus une action supplementaire dans le parcours standard.
- Un feedback local `Connecting` apparait immediatement apres l'action. La cible du premier evenement BDK reel est fixee apres les mesures Wi-Fi/cellulaire du spike, sans fabriquer un faux pourcentage.
- Aucune page n'affiche un spinner sans libelle, progression ou action pendant plus de 2 secondes.
- Une interruption/reprise normale ne produit ni snackbar d'erreur ni retour apparent a zero si les donnees Kyoto permettent de recalculer l'avancement conserve.
- Les tests UI couvrent 0 %, progression, warning recuperable, offline, annulation, reprise, 100 % et fallback Electrum.
- Les tests de comprehension internes doivent confirmer que l'utilisateur comprend deux faits : ses adresses ne sont pas envoyees au serveur de scan, mais son IP n'est pas cachee en V1.

## Phase 3 : foreground, arriere-plan et reprise

Objectif : ne jamais promettre un comportement que les OS ne garantissent pas.

| Contexte | Comportement cible | Limite |
|---|---|---|
| Premier scan ou "Synchroniser" en foreground | Scan CBF continu, progression determinee et annulation. | Le processus doit rester vivant. |
| Android, utilisateur veut continuer hors app | Evaluer un Worker long avec foreground service `dataSync`, notification et progression native, seulement apres le spike. | Android 15 limite le type `dataSync` a six heures par periode de 24 h ; Doze et connectivite peuvent retarder le travail. |
| iOS < 26 | Au passage background, arreter proprement ou laisser le systeme accorder un bref temps ; reprise au retour. Une tache BG est un catch-up sans promesse de progression. | `BGProcessingTask` est planifie a discretion par le systeme. |
| iOS 26+ | Evaluer `BGContinuedProcessingTask` pour une action explicitement initiee par l'utilisateur, avec Live Activity et annulation systeme. | API recente, seulement iOS 26+, necessite un fallback. |
| Tache periodique existante | Aucun CBF en V1. Evaluer plus tard une tentative bornee qui reutilise les donnees persistantes. | Pas de garantie d'execution ou de terminaison. |

La premiere version produit est strictement foreground. Sur toute sortie de `AppLifecycleState.resumed`, Bull demande le shutdown et persiste l'etat ; les appareils reels doivent prouver que cette fermeture finit avant suspension. Le service foreground Android, `BGProcessingTask` et `BGContinuedProcessingTask` iOS sont des increments platformes distincts, absents de la V1.

Critere de sortie V1 : reprise apres kill, bascules rapides lifecycle, double annulation sans exception visible, et aucun socket/noeud CBF orphelin. Les criteres background sont definis seulement dans les PRs plateformes futures ; le produit doit rester correct si une tache iOS ne s'execute jamais.

## Phase 4 : mempool, broadcast et swaps

Objectif : conserver les garanties fonctionnelles qui ne sont pas fournies par CBF.

1. Conserver `FeesDatasource` tel quel : les frais Bitcoin sont deja obtenus par API mempool et ne dependent pas d'Electrum.
2. Ne pas basculer automatiquement le broadcast des flux sensibles vers le P2P CBF. Auditer tous les consommateurs du retour de broadcast avant une modification.
3. Garder Electrum pour `SwapWatcher`. Tester `missingorspent` et `non-final` avec un et plusieurs serveurs, car le fallback traite par defaut toute `Exception` comme transitoire et peut masquer le premier rejet.
4. Decider separerement si l'API mempool est utilisee pour les receptions pending ou le suivi d'un envoi local. Si oui, limiter les appels aux scripts d'une demande de paiement active ou aux transactions explicitement suivies, exposer la fuite de confidentialite et honorer serveur personnalise/Tor. Ne jamais utiliser cette API pour refaire un scan global des scripts.
5. Tester Payjoin contre `bdk-kyoto#136`; garder Payjoin sur Electrum ou le desactiver pour CBF si les prevouts/frais ne sont pas tous verifies.
6. Afficher l'etat "en attente de confirmation" pour les flux ou CBF ne peut pas observer une entree mempool ; ne jamais crediter ou declencher une action irreversible sur cette observation.

Critere de sortie : tests de broadcast rejete mono/multi-serveurs, lockup deja depense, locktime non final, Payjoin avec prevouts etrangers, transaction entrante pending/confirmee, plus revue de securite explicite.

## Phase 5 : deploiement prudent

1. Livrer derriere un feature flag de developpement puis beta volontaire, sans migration automatique.
2. Collecter uniquement des metriques agregees et non sensibles : temps de scan, taille de repertoire, taux de reprise, classes de warnings et echecs. Ne jamais envoyer des adresses, scripts, descripteurs, peers, IP ou materiel de cle.
3. Definir une sortie de secours : l'utilisateur peut revenir a Electrum ; le changement de backend preserve le wallet BDK mais initialise le stockage du nouveau backend. Ne supprimer les donnees CBF qu'apres confirmation de l'utilisateur ou politique documentee.
4. Etablir des seuils de go/no-go : crash FFI, corruption de base, echec de sync/reprise, consommation batterie, espace disque, reussite des tests swaps et taux de warnings sans recuperation.

## Questions a trancher avant le spike

1. Decision proposee : backend persiste par wallet, avec un defaut global venant du wizard pour les nouveaux wallets seulement. Les wallets existants restent Electrum.
2. Quelle politique de bootstrap clearnet est acceptable pour la V1 : DNS seeds Kyoto, liste IP Bull, ou combinaison ? Tor est reporte a la porte GT.
3. Bull veut-il demander a l'equipe `bull_sdk` un bump du pin `bdk-ffi` vers une revision >= PR #1047 des maintenant ? Ce bump est le prerequis de GT et peut etre prepare en parallele de la V1 sans l'activer.
4. Quand `useTorProxy` est actif, la V1 bloque-t-elle le choix CBF ou le permet-elle avec confirmation explicite ? La recommandation par defaut est le blocage avec explication, plus simple a comprendre.
5. Bull accepte-t-il le compromis produit "reception visible seulement apres confirmation" pour les wallets CBF, ou souhaite-t-il une API mempool limitee pour les demandes de paiement actives ?
6. Decision V1 proposee : Electrum reste le backend de broadcast pour tous les flux Bitcoin. Tout changement futur exige une revue securite separee.
7. Quelle retention/espace disque est acceptable pour les donnees headers/peers CBF ?
8. Le choix doit-il aussi etre propose dans tous les imports/recoveries et le backup-test, ou seulement a la creation de wallet ?
9. La parite RBF/CPFP des envois propres (porte G3) est-elle exigee pour la premiere beta, ou une beta "confirme uniquement" est-elle acceptable ?

## Verification requise par PR

- `make analyze`
- `make unit-test`
- tests d'integration BDK/CBF marques et executables sur testnet
- essais manuels Android et iOS reels avec rapport de version d'OS/appareil
- revue securite lorsque le changement touche Tor, peers, broadcast ou swaps
- checklist UX de la Phase 2 pour toute PR visible par l'utilisateur
- roadmap de PR : `docs/compact-block-filters-pr-roadmap.md`
