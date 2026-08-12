# Statoo — Design system

> **Révision du 12/08/2026 — l'interdit de gamification décrit plus bas est levé
> pour tout ce qui relève du décor.** Emoji, icônes expressives, illustrations
> d'états vides, médailles au classement et micro-animations sont désormais
> permis. Seules les mécaniques de **données** restent hors périmètre : note de
> joueur, vote du homme du match, badge / série / niveau stocké — l'argument
> d'origine étant le caractère mono-utilisateur de l'app, qui lui n'a pas changé.
> La règle en vigueur est la section *Ton* de `CLAUDE.md`. Le texte ci-dessous
> est conservé tel quel : il documente le raisonnement initial, pas la règle
> actuelle.

**Version** 1.0 · **Cible** V1 (APK Android) · **Base** Nuxt UI + Tailwind v4

---

## 1. Benchmark — ce que fait le domaine

Trois familles d'applications occupent le terrain, et aucune ne vise le même
problème que Statoo.

| Famille | Exemples | Ce qu'elles optimisent | Langage visuel |
|---|---|---|---|
| Kickabout social | Capo, Five, KickAbout.Me | l'engagement du groupe entre deux matchs | fantasy football : badges, tiers de rareté, streaks 🔥, profils de joueurs |
| Gestion de club | SportEasy, Spond | la logistique (convocations, présences, paiements) | administratif : calendriers, listes, formulaires |
| Data spectateur | Sofascore, FotMob, FootyStats | la densité d'information sur des matchs qu'on ne joue pas | sombre, dense, temps réel, heatmaps |

Ce qu'elles font toutes et que Statoo ne fera pas : <cite index="12-1">le vote du homme du match, les séries en cours, plus de 200 succès à débloquer avec artwork et niveaux de rareté</cite>, les notes de joueurs, la composition d'équipes assistée. Ce sont des mécaniques
multi-utilisateurs : elles n'ont aucun sens quand une seule personne ouvre l'app.

### Ce qu'on retient quand même

1. **La boucle post-match doit tenir en un écran.** Capo revendique <cite index="16-1">le pool de joueurs, les équipes, la saisie du score et le bouton de fin, l'après-match tenant en un seul geste</cite>. C'est exactement le critère « < 2 min » du cahier des charges. Cette contrainte doit se voir dans la mise en page, pas seulement dans le code.
2. **Le classement est le produit.** C'est l'écran qu'on rouvre le mardi soir. Il mérite le meilleur traitement typographique de l'app.
3. **La note de joueur est un piège.** Les concurrents la construisent parce qu'ils en ont besoin pour équilibrer les équipes. Statoo tire au sort (`RandomSplitter`) : aucune note, aucun tier, aucune étoile. La sobriété est ici un choix produit, pas un manque.

### Positionnement retenu

> Statoo n'est pas un réseau social de foot. C'est **le carnet de l'organisateur** :
> un objet qui se remplit au bord du terrain, dans le bruit, à une main, et qui
> restitue des chiffres honnêtes.

Deux conséquences directes sur le design : **la saisie prime sur la consultation**,
et **rien n'est décoré qui ne soit dérivé de `participations`**.

---

## 2. Direction artistique

### 2.1 Le thème : le terrain de nuit

Une séance, c'est une soirée. Écran allumé au bord d'un synthétique sous
projecteurs. La palette vient de là : un vert-noir très désaturé (le gazon la nuit,
jamais le vert vif d'un logo de club), la craie des lignes, et un seul accent —
**le jaune dossard**, la couleur qu'on met justement sur des gens pour qu'on les
distingue de loin dans une mauvaise lumière.

C'est le seul argument dont j'ai besoin pour cet accent : il est haute visibilité
par fonction, pas par mode.

### 2.2 Le principe structurant : A et B sont à égalité

Toutes les apps de score empruntent la hiérarchie domicile / extérieur : une équipe
est le sujet, l'autre est l'adversaire. Dans un 5x5 entre amis, les deux équipes
sont le même groupe d'amis coupé en deux. **Aucune des deux ne peut être primaire.**

L'écart se joue donc sur la matière, comme sur le terrain : une équipe porte les
dossards, l'autre joue en tenue.

- **Équipe A** — aplat jaune dossard.
- **Équipe B** — contour craie, remplissage hachuré à 45°.

Distinction qui survit au daltonisme, au plein soleil et à une capture d'écran en
noir et blanc. Elle ne dit rien de qui est favori, parce que rien ne le dit.

### 2.3 Signature : le bandeau de score

Un unique dispositif graphique, décliné à quatre tailles, jamais décoratif :
une barre horizontale divisée **proportionnellement au score**.

```
4 — 2   ████████████████████╱╱╱╱╱╱╱╱╱╱

2 — 2   ██████████████╱╱╱╱╱╱╱╱╱╱╱╱╱╱

0 — 3   ╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱
```

- **2 px** en tête de ligne dans la liste des séances → on lit le résultat en scrollant, sans lire les chiffres.
- **6 px** sur la carte « dernière séance » de l'accueil.
- **40 px** en tête du détail de séance, chiffres posés dessus.
- **1 px** comme séparateur entre les deux colonnes de composition.

Cas limites, à traiter explicitement : `0 — 0` affiche la barre coupée en deux
parties vides séparées par un trait ; une séance `DRAFT` affiche la barre en
pointillés, non remplie. La barre ne ment jamais sur un score absent.

### 2.4 Ce que je n'ai pas fait, et pourquoi

- **Pas de dégradés, pas de glow, pas de verre dépoli.** L'app est consultée en
  extérieur ; tout ce qui baisse le contraste est une régression fonctionnelle.
- **Pas de vert « gazon » saturé, pas de ballon en illustration.** Le sujet est
  déjà dans la structure ; le redire en image serait redondant.
- **Un seul thème (sombre).** Une séance se joue le soir. Deux thèmes, c'est deux
  fois la surface de bug pour un usage qui n'existe pas.

---

## 3. Tokens

### 3.1 Couleur

Trois échelles. `pitch` sert de neutre (fond, texte, bordures), `bib` d'accent
unique, `flag` d'alerte. Rien d'autre n'est autorisé.

```css
/* app/assets/css/main.css */
@import "tailwindcss";
@import "@nuxt/ui";

@theme {
  /* pitch — neutre, gazon désaturé sous projecteur */
  --color-pitch-50:  #EAF0EC;
  --color-pitch-100: #D3DED8;
  --color-pitch-200: #B0C0B8;
  --color-pitch-300: #8CA096;
  --color-pitch-400: #6E837A;
  --color-pitch-500: #556860;
  --color-pitch-600: #3F4E48;
  --color-pitch-700: #2A3831;
  --color-pitch-800: #1B2721;
  --color-pitch-900: #121B17;
  --color-pitch-950: #0B120F;

  /* bib — jaune dossard, accent unique + équipe A */
  --color-bib-50:  #FFF9EB;
  --color-bib-100: #FFEFC7;
  --color-bib-200: #FFE29E;
  --color-bib-300: #FFD470;
  --color-bib-400: #FFC94F;
  --color-bib-500: #F5B32E;
  --color-bib-600: #D9971C;
  --color-bib-700: #AE7614;
  --color-bib-800: #7C5310;
  --color-bib-900: #4E340A;
  --color-bib-950: #2B1D05;

  /* flag — carton, alerte, destructif */
  --color-flag-50:  #FFF1EE;
  --color-flag-100: #FFDCD5;
  --color-flag-200: #FFBCAF;
  --color-flag-300: #FF9585;
  --color-flag-400: #FF7361;
  --color-flag-500: #F0503C;
  --color-flag-600: #CB3A28;
  --color-flag-700: #A22C1E;
  --color-flag-800: #731F15;
  --color-flag-900: #47130D;
  --color-flag-950: #260907;
}
```

```ts
// app.config.ts
export default defineAppConfig({
  ui: {
    colors: {
      primary: 'bib',
      neutral: 'pitch',
      error: 'flag',
      warning: 'bib',
    },
  },
})
```

Nuxt UI exige les nuances 50 → 950 pour toute couleur personnalisée ; les trois
échelles ci-dessus sont complètes.

**Rôles sémantiques** (à utiliser dans le code, jamais la nuance brute) :

| Rôle | Valeur | Usage |
|---|---|---|
| `bg` | `pitch-950` | fond d'écran |
| `surface` | `pitch-900` | cartes, lignes de liste |
| `surface-raised` | `pitch-800` | champs, compteurs, feuilles modales |
| `border` | `pitch-700` | filets 1 px |
| `text` | `pitch-50` | texte principal, chiffres |
| `text-muted` | `pitch-300` | labels, méta, joueurs archivés |
| `accent` | `bib-400` | action principale, équipe A, rang 1 |
| `alert` | `flag-400` | avertissement buts, carton rouge, destruction |

Le jaune est un accent d'action **et** la couleur de l'équipe A. Pas de conflit
tant qu'on tient une règle : dans un écran de séance, aucun bouton n'est jaune
plein sauf « Clôturer la séance ». Partout ailleurs le jaune signifie « équipe A ».

### 3.2 Typographie

Deux familles variables, sous-ensemble latin, chargées par `@nuxt/fonts`.

| Rôle | Fonte | Justification |
|---|---|---|
| Chiffres et titres | **Archivo Expanded** 600–700 | la grotesque large est le vernaculaire du numéro de maillot et du tableau d'affichage. Les chiffres tiennent la ligne à 44 px. |
| Interface | **Instrument Sans** 400–600 | étroite, très lisible à 13–15 px, ne se bat pas avec Archivo. |

```css
@theme {
  --font-display: 'Archivo Expanded', 'Archivo', system-ui, sans-serif;
  --font-sans: 'Instrument Sans', system-ui, sans-serif;
}
```

Tous les chiffres alignés en colonne portent `font-variant-numeric: tabular-nums`.
Non négociable dans le classement : sans ça, les colonnes dansent au scroll.

**Échelle**

| Token | Taille / interligne | Fonte | Usage |
|---|---|---|---|
| `score` | 44 / 1.0 | Display 700 | score de séance |
| `stat-xl` | 32 / 1.05 | Display 700 | chiffre clé de la fiche joueur |
| `title` | 20 / 1.2 | Display 600 | titre d'écran, nom de joueur en fiche |
| `body` | 15 / 1.45 | Sans 400 | texte courant |
| `data` | 15 / 1.2 | Display 500, tnum | cellules du classement |
| `label` | 13 / 1.3 | Sans 500 | libellés de champ, méta de ligne |
| `eyebrow` | 11 / 1.0 | Sans 600, `0.08em`, capitales | en-têtes de colonne, libellés de stat |

### 3.3 Espacement, rayons, élévation

```css
@theme {
  --spacing: 4px;              /* échelle 4 · 8 · 12 · 16 · 24 · 32 · 48 */
  --radius-sm: 4px;            /* badges, puces */
  --radius-md: 8px;            /* champs, boutons */
  --radius-lg: 14px;           /* cartes, feuilles modales */
  --text-tap: 44px;            /* cible tactile minimale */
  --text-tap-lg: 52px;         /* compteurs +/- */
}
```

Pas d'ombres portées : sur un fond sombre elles ne se voient pas. La hiérarchie
se fait par la valeur du fond (`950` → `900` → `800`) et par un filet 1 px.

### 3.4 Mouvement

Un seul moment orchestré dans toute l'app : **la clôture**. Le bandeau de score se
remplit de 0 à sa proportion finale en 320 ms `cubic-bezier(.2,.8,.2,1)`, puis le
classement se réordonne en FLIP 240 ms. C'est le seul endroit où l'app se permet
de raconter quelque chose, parce que c'est le seul moment où un chiffre change
vraiment.

Partout ailleurs : 120 ms sur les états pressés, rien d'autre. Aucune transition
de page. `prefers-reduced-motion: reduce` coupe tout et applique l'état final.

---

## 4. Composants

### 4.1 ScoreBar — le composant signature

```
Props: scoreA, scoreB, status, size ('xs' | 'sm' | 'md' | 'lg')
```

- Aplat `bib-400` à gauche, hachures `pitch-300` à 45° sur `pitch-800` à droite.
- Largeurs = `scoreA / (scoreA + scoreB)`, avec un minimum de 4 px par côté pour
  qu'une équipe à 0 reste visible.
- `status === 'DRAFT'` → contour pointillé, aucun remplissage.
- `aria-label` : « Équipe A 4, équipe B 2 ». Le composant n'est jamais la seule
  source de l'information : le score chiffré est toujours à côté.

### 4.2 StatStepper — le composant le plus utilisé

C'est lui qui décide si la saisie tient en deux minutes.

```
[ − ]   3   [ + ]      buts
 52px  40px  52px
```

- Cibles de 52 px, alignées à droite de l'écran (pouce droit), la valeur au centre.
- Appui long sur `+` → incrément accéléré après 500 ms.
- `−` désactivé à 0, jamais masqué (la position ne bouge pas).
- Retour haptique léger à chaque incrément : au bord du terrain on ne regarde pas
  toujours l'écran.
- Pas de champ texte. Aucun clavier ne s'ouvre pendant la saisie des stats.

### 4.3 PlayerRow

Ligne à trois zones : identité (avatar 36 px ou initiales sur `pitch-800`), nom +
surnom, puis trois chiffres en `data` alignés à droite (J / pts / buts).
Joueur archivé : identité et nom en `text-muted`, avatar à 50 % d'opacité, badge
« Archivé » en `eyebrow`. Il reste lisible — il est toujours au classement.

### 4.4 StandingsTable

- Colonnes : rang · joueur · **J** · V · N · D · Pts · Pts/m.
- Rang 1 : le numéro en `bib-400`, rien d'autre. Pas de médaille, pas de fond doré.
- La colonne **J** est toujours visible, jamais repliée sous un « voir plus » :
  c'est la clé de lecture du classement par points.
- Sous le seuil des 50 %, dans l'onglet Pts/match : bloc séparé sous un filet, en
  `text-muted`, avec le décompte réel — « il manque 3 séances », pas « non éligible ».
- Scroll horizontal interdit. Si ça ne tient pas, on retire une colonne, on ne
  fait pas glisser le tableau.

### 4.5 Badges et bandeaux

| État | Traitement |
|---|---|
| `DRAFT` | contour `pitch-600`, texte `pitch-300` |
| `CLOSED` | aucun badge — c'est la norme, on ne badge pas la norme |
| Amical (`is_ranked = 0`) | contour `pitch-600`, texte `pitch-100` |
| Écart de buts (`has_goal_mismatch`) | pastille `flag-400` 6 px en liste ; bandeau `flag-950` + filet `flag-700` en détail |

Le bandeau d'avertissement de la règle 4 est **informatif, pas bloquant** — donc il
n'est pas rouge plein, il ne prend pas le focus, et il ne contient pas de bouton
« Corriger ». Il énonce l'écart et laisse clore.

> **Écart de buts** — Équipe A : 4 marqués, 3 attribués. Vous pouvez clore quand même.

### 4.6 Confirmations destructives

Feuille modale par le bas, jamais de `dialog` centré (hors de portée du pouce).
Bouton destructif en `flag-500` plein, **en bas**, l'annulation au-dessus.
Trois cas seulement : écraser une composition, rouvrir une séance close,
restaurer un backup. La restauration exige en plus de retaper le nom du groupe —
c'est la seule action irréversible de l'app.

### 4.7 États vides

Un état vide est une invitation, pas un décor. Pas d'illustration.

| Écran | Texte |
|---|---|
| Séances | « Aucune séance. La première prend deux minutes. » + `Nouvelle séance` |
| Joueurs | « Ajoutez les joueurs du groupe pour commencer. » + `Nouveau joueur` |
| Classement | « Le classement apparaîtra après la première séance close. » |
| Backups | « Aucune sauvegarde. Elle se déclenchera à la prochaine clôture. » |

---

## 5. Navigation et écrans

Barre d'onglets basse, 5 entrées, icônes + libellés (le libellé seul est trop
étroit pour 44 px de cible confortable) : **Accueil · Joueurs · Séances ·
Classement · Stats**. Réglages en icône dans l'en-tête de l'accueil.

**Accueil** — la carte « dernière séance » avec son bandeau de score en 6 px, un
bouton `Nouvelle séance` pleine largeur en `bib-400`, le top 3 du classement, et
en pied de page l'état du backup en `eyebrow` : « Sauvegardé il y a 2 jours » ou
« Sauvegarde en attente » en `flag-400`.

**Détail de séance** — l'écran critique. Bandeau de score 40 px en tête, deux
colonnes A / B séparées par un filet 1 px, chaque joueur portant ses quatre
`StatStepper` en accordéon (un seul joueur ouvert à la fois). Barre d'action
collée en bas : `Clôturer la séance`, pleine largeur, 56 px.

---

## 6. Écriture

- **Impératif, voix active, casse de phrase.** « Clôturer la séance », pas
  « Clôture » ni « Valider ». Un même mot du bouton au toast : `Clôturer` →
  « Séance clôturée ».
- **Le vocabulaire du groupe, pas celui de la base.** « Séance », « présents »,
  « amical », « archivé ». Jamais `is_ranked`, `DRAFT`, `participation`.
- **Les erreurs disent quoi et comment.** « Renseignez les deux scores pour
  clore. » Pas « Formulaire invalide ». Elles ne s'excusent pas.
- **Les chiffres ne sont pas commentés.** Aucun « Belle performance ! » sous une
  moyenne. L'app compte, elle ne juge pas — c'est la traduction en copy de la
  règle 1.

---

## 7. Accessibilité — plancher non négociable

- Contraste ≥ 4.5:1 sur tout texte (`pitch-300` sur `pitch-950` ≈ 7:1, `pitch-50`
  sur `bib-400` ≈ 11:1 pour le texte sur bouton jaune).
- Cibles ≥ 44 px, 52 px pour les compteurs.
- La couleur n'est jamais seule porteuse de sens : A/B se distinguent aussi par la
  hachure, les avertissements par leur texte, le rang 1 par sa position.
- `prefers-reduced-motion` respecté.
- Étiquettes `aria` sur les steppers : « Buts de Karim, 3, augmenter ».

---

## 8. Mise en œuvre

1. `main.css` : les trois `@theme` (couleur, fonte, rayons) — la seule source de vérité des valeurs.
2. `app.config.ts` : le mappage sémantique `primary: 'bib'`, `neutral: 'pitch'`, `error: 'flag'` et les variantes par défaut des composants Nuxt UI (`button: { defaultVariants: { size: 'lg' } }`).
3. `app/components/ui/` : les quatre composants qui n'existent pas dans Nuxt UI — `ScoreBar`, `StatStepper`, `PlayerRow`, `StandingsTable`. Rien d'autre n'est enveloppé : `UButton`, `UBadge`, `UModal`, `UTable` sont utilisés directement.

Aucune valeur brute (`#FFC94F`, `text-[13px]`) hors de `main.css`.

---

## 9. Points à trancher

Ces trois éléments touchent le cahier des charges et ne sont **pas** appliqués :

- **Colonne « forme » (5 derniers résultats).** Dérivable de `participations`,
  donc compatible règle 1, mais absente de la spécification et demandant une vue
  supplémentaire. À arbitrer, pas à glisser.
- **Le jaune comme accent d'action et comme couleur d'équipe A.** Tenable avec la
  règle énoncée en §3.1, mais si elle vous paraît fragile, l'alternative est un
  accent d'action neutre (`pitch-50` plein) et le jaune réservé à l'équipe A.
- **Thème clair.** Écarté. Si la saisie se fait souvent en plein jour, la décision
  est à reprendre avant d'écrire une ligne de CSS, pas après.
