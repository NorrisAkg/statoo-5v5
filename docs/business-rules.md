# Règles et workflows métier

Comportement confirmé par lecture du code au 12 octobre 2026. Les arbitrages encore requis sont dans [le registre](decisions-and-risks.md).

## Groupes et joueurs

Chaque groupe possède joueurs et séances. Le groupe actif est conservé dans SQLite et SharedPreferences. Le premier lancement propose création ou restauration.

Les joueurs sont créés, édités, archivés et réactivés. Le nom est vérifié dans le groupe avant création ; cette vérification n'est pas une contrainte UNIQUE SQLite. Un joueur avec participations ne peut pas être supprimé ; l'archivage préserve son historique.

Sources : `lib/features/team/data/team_repository.dart`, `lib/features/team/presentation/create_team_screen.dart`, `lib/features/players/application/players_provider.dart`, `lib/features/players/data/players_repository.dart`.

## Création et suivi

1. Choisir date/heure et options : classée/amicale, équipes inégales, type de séance.
2. Sélectionner les présents, affecter les camps manuellement ou par mélange aléatoire.
3. Vérifier le minimum du groupe (défaut 6) et l'équilibre.
4. Enregistrer le brouillon, démarré si aucune séance n'est déjà active dans le groupe.
5. Saisir scores et statistiques ; ajouter des retardataires, changer de camp ou retirer une participation selon les contraintes d'effectif.

Une séance active est un DRAFT référencé dans meta par active_session_id_<teamId>, pas un troisième statut SQL. Une seule référence active est maintenue par groupe.

Sources : `lib/features/sessions/presentation/new_session_screen.dart`, `lib/features/sessions/application/sessions_provider.dart`, `lib/features/settings/application/settings_provider.dart`.

## Classique et tournoi

Classique : camps A/B, initialisation à 0-0 avec résultat nul. Attribuer un but consomme d'abord ceux déjà comptés au score sans attribution ; seul le surplus augmente le score. Retirer/déplacer un but attribué ne diminue pas automatiquement le score.

Tournoi : camps A/B/C, résultat selon le maximum de victoires ; toutes les victoires à zéro donnent un résultat absent. Égalité entre deux ou trois camps possible. Les points d'égalité sont copiés depuis le réglage du groupe (défaut 1). Aucun modèle de rencontre interne ni calendrier de poule n'est présent. Les scores classiques ne sont pas initialisés.

Sources : `lib/features/sessions/domain/session.dart`, `lib/features/sessions/domain/goal_score_sync.dart`, `lib/features/sessions/domain/session_close_rules.dart`, `lib/features/sessions/application/sessions_provider.dart`.

## Clôture et correction

Les bloqueurs sont : score/résultat requis absent, écart d'effectif > 1 sans dérogation, incohérence buts/score lorsque les scores sont présents, passes d'un camp supérieures à ses buts joueurs, ou buts + passes d'un joueur supérieurs aux buts joueurs de son camp (contrôle agrégé d'auto-passe).

L'unicité du joueur par séance est garantie par SQLite. Le contrôleur relit séance/participants et valide ; le repository clôture seulement un DRAFT avec résultat et scores requis, puis retire sa référence active dans la même transaction. Validation complète et écriture ne forment pas une transaction unique.

Rouvrir remet en DRAFT sans activer automatiquement ; supprimer entraîne suppression des participations.

Sources : `lib/features/sessions/domain/session_close_rules.dart`, `lib/features/sessions/application/sessions_provider.dart`, `lib/features/sessions/data/sessions_repository.dart`.

## Classements et statistiques

Points : séances CLOSED classées uniquement, victoire 3/nul classique 1/défaite 0 ; égalité de tournoi selon draw_points. Classement principal : points, victoires, matchs joués, nom. Le ratio exige au moins 50 % des séances classées closes et exclut les archivés ; le classement principal les conserve.

Les statistiques brutes incluent les amicaux clos. Les totaux de buts du groupe utilisent les scores, les passes/cartons utilisent les participations.

MVP mensuel : séances closes classées, au moins une participation, au plus une absence. Poids par défaut : victoire 10, nul 3, défaite 0, but +2, passe +1, jaune -0,5, rouge -1. Score moyen arrondi à deux décimales ; poids configurables par groupe. Le poids MVP du nul est distinct des points d'égalité du championnat.

Sources : `lib/core/data/app_database.dart`, `lib/features/ranking/data/ranking_repository.dart`, `lib/features/ranking/domain/mvp_calculator.dart`, `lib/features/ranking/domain/mvp_weights.dart`.

## Noms et couleurs des camps

Après affectation des présents, chaque camp peut recevoir un nom et une couleur parmi huit pastilles. Les champs sont facultatifs : un nom vide utilise Équipe A/B/C et une couleur non choisie garde le défaut. La création est bloquée si les noms effectifs sont identiques après trim et sans distinction de casse, ou si les couleurs effectives sont identiques. En tournoi, les trois camps doivent être distincts. Les noms/couleurs sont conservés par séance et affichés dans son détail. Une réinitialisation restaure le défaut du camp.

Sources : lib/features/sessions/domain/team_appearance.dart, lib/features/sessions/presentation/team_appearance_editor.dart, lib/features/sessions/application/sessions_provider.dart.
