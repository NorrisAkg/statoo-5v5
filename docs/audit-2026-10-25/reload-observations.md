# AUD-18 — Rechargement direct des statistiques

Observation interactive du 25 octobre 2026, navigateur intégré, build courant
1daa008 compilé pour l’audit, origine locale http://127.0.0.1:19225/.
Groupe fictif « Audit Statoo local », six joueurs, une séance classique close 1-0,
un but d’Alice Audit et une passe de Fatou Audit.

## Premier passage

1. Après clôture, navigation vers Classement : gagnants 3 points, perdants 0.
2. Navigation vers `#/stats` : 1 séance, 6 actifs, 1 but, 1 passe. Rendu et arbre accessibles observés.
3. Rechargement de `#/stats`, puis lecture après disparition du chargement : 0 séance, 0 actif, 0 but, 0 passe.
4. Passage par Accueil : nom du groupe retrouvé ; après chargement, dernière séance 1-0 et classement retrouvés.
5. Retour vers Stats : 1 séance, 6 actifs, 1 but, 1 passe.

## Confirmation après écriture du scénario AUD-18

6. Les valeurs correctes de Stats sont relevées avant un second rechargement.
7. Rechargement direct de la même route ; après l’écran de chargement, retour durable à zéro.

Extraits de l’arbre d’accessibilité observé :

Avant :
```
1 Séances jouées 1 classées 6 Joueurs actifs Sur 6 inscrits au total
1 Buts totaux Score global des séances 1.0 Moyenne / séance
Passes décisives Enregistrées lors des séances 1
```

Après :
```
0 Séances jouées 0 classées 0 Joueurs actifs Sur 0 inscrits au total
0 Buts totaux Score global des séances 0.0 Moyenne / séance
Passes décisives Enregistrées lors des séances 0
```

Les captures ont été vues dans les sorties du navigateur de cette conversation.
Cette note restitue les observations ; elle n’est pas un log de test automatisé.
Le rétablissement par l’accueil distingue le défaut d’initialisation du groupe actif
d’une perte des enregistrements SQLite. Aucun effacement ni réinitialisation du
stockage n’a été demandé entre les étapes.

Lecture concordante : main.dart initialise hasTeam mais pas activeTeamIdProvider ;
ce dernier commence à null. TeamInfoNotifier charge le groupe et lance selectTeam
lorsqu’un écran le consomme. Stats retourne un modèle vide lorsque l’identifiant
de groupe actif est null. Aucun correctif dans cet audit.
