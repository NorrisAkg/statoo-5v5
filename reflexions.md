# Mes réflexions

Un espace libre pour noter mes idées, mes questions et mes envies.

**Suivi :** `[ ]` = en attente · `[x]` = traité. Une idée à analyser n’est pas encore une décision d’implémentation.

## Notes du 15 octobre 2026

### Ce que j’ai en tête
- Après la clôture, des confetis plus un message de félicitations à l'équipe gagnante de la séance, ou un message adapté au nul (Ex: Ouooh, c'était serré aujourd'hui. Bravo à tous.
- Pour la cotisation, pré-remplir tous les champs cotisation de la séance par le montant paramétré; cela évitera au TG ou TGA de taper dans le champ devant les noms qui ont payé le montant exact de la séance
- Permettre de paramétrer l'affichage de la section "Joueur du mois sur l'accueil" et adapter l'affichage du reste des blocs sur l'accueil en fonction de ça.

#### Traités

- [x] **Saisie des statistiques pendant le match — intégrée.** Je trouve que le processus de saisie des stats pendant le match pourrait être optimisé pour faire gagner un peu plus de temps. Plutôt que d'incrémenter et de sauvegarder à chaque fois, on pourrait se passer de la sauvegarde par stat saisie et sauvegarder les stats de toute la séance en une fois avec un modal de confirmation. C'est juste une idée; j'attends de toi que tu analyses et me fasses d'autres propositions éventuellement, en te mettant dans la peau d'un expert UI/UX.
  - Attendu : analyser le parcours actuel et comparer les options avant de choisir une solution. Prendre en compte la rapidité de saisie, la correction des erreurs et la conservation des modifications en cas d’interruption.
  - Choix validé puis intégré le 17 octobre : saisie par événement, buteur et passeur réunis, conservation locale automatique, correction et annulation, victoires indépendantes en tournoi ; confirmation à la clôture. Flutter commun mobile/web. Tests automatisés et Chrome vérifiés ; recette physique et synchronisation réelle multiappareils restantes. [Preuves](docs/tdd-live-integration.md).

- [x] **Noms d’équipes aléatoires.** Je voudrais qu'on crée une longue liste de noms d'équipe. Le but c'est de ne plus demander le nom des équipes constituées pour une séance, mais juste choisir deux noms aléatoirement dans la liste. Le choix des couleurs restera possible. Cela fera gagner du temps et surchagera moins l'écran.
  - Réalisé : catalogue de noms réalistes, tirage de deux noms pour un match ou trois pour un tournoi ; couleurs personnalisables.
  - Référence : [tests des noms d’équipes](mobile/test/features/sessions/session_team_names_test.dart).
- [x] **Dernière séance affichée sur l’accueil.** L'affichage de la dernière séance sur l'accueil n'est pas correcte. Je viens de terminer une séance à 3 équipes, mais ce n'est pas cette séance qui s'affiche à l'accueil
  - Réalisé : sélection de la dernière séance terminée, y compris les tournois à trois équipes, et affichage des buteurs.
  - Référence : [tests de la dernière séance](mobile/test/features/home/latest_session_test.dart).

### Idées à explorer

- 

### Questions en suspens

- [ ] Une séance distante est-elle différente d'une séance locale ?
- [ ] Où en est la version web ? Est-elle bien alignée sur le mobile et est-elle mobile first ?
- [ ] Quelles sont les étapes du onboarding maintenant qu'on a introduit les rôles ?

### Prochaines pistes

- [ ] 

---

## Notes libres


