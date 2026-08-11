# Statoo — Prompt Google Stitch

**Mode** : Mobile (Android) · **Thème** : sombre uniquement · 18 écrans

---

## Mode d'emploi

Google Stitch dégrade fortement au-delà de ~1 écran par requête. La méthode qui
fonctionne :

1. Coller **le bloc A (Global style)** dans la première requête, avec l'écran 1.
2. Générer les écrans **un par un**, en collant à chaque fois le bloc A abrégé
   (`Same style as before:` + les 6 lignes de couleur) suivi du prompt de l'écran.
3. Les libellés d'interface sont en **français** et doivent être repris
   littéralement — Stitch a tendance à les traduire en anglais. La ligne
   « Use the exact French labels below, do not translate » est dans le bloc A ;
   la garder à chaque requête.
4. Les hachures 45° (équipe B) ne sont pas toujours rendues. Si Stitch les ignore,
   le fallback accepté est un contour 1 px + fond `#1B2721`, jamais une seconde
   couleur pleine.

---

## BLOC A — Global style (à coller en tête de chaque requête)

```
Mobile app UI, Android, 390x844. Dark theme only, no light mode.

App: Statoo — a private notebook for the organiser of a weekly 5-a-side football
game among friends. Single user, offline. It records a session in under two
minutes at the edge of the pitch, one-handed, and shows honest numbers. It is NOT
a social app: no badges, no achievements, no player ratings, no stars, no streaks,
no trophies, no medals, no emoji, no gamification of any kind.

COLORS (use these exact hex values, no others):
- Background #0B120F (desaturated dark green-black)
- Card / list surface #121B17
- Raised surface, inputs, steppers #1B2721
- Hairline borders #2A3831
- Primary text #EAF0EC
- Muted text #8CA096
- Accent (buttons, team A, rank 1) #FFC94F (high-visibility bib yellow)
- Alert / destructive / red card #F0503C

TYPE:
- Numbers, scores and titles: Archivo Expanded, weight 700, tabular figures.
- Interface text: Instrument Sans, 15px body, 13px labels.
- Column headers and stat labels: 11px, uppercase, letter-spacing 0.08em, #8CA096.
- All numbers in a column are tabular and right-aligned.

TEAM ENCODING (critical, applies everywhere):
Team A and Team B are strictly equal in hierarchy — never a home/away style layout.
They are distinguished by material, not by importance:
- Team A = solid #FFC94F fill.
- Team B = 1px #556860 outline with 45-degree diagonal hatching over #1B2721.
Never use a second solid color for team B.

SIGNATURE ELEMENT — the score bar:
A single horizontal bar split in proportion to the score: the left part solid
#FFC94F sized to team A's goals, the right part hatched sized to team B's goals.
Minimum 4px per side so a team on 0 stays visible. A draft session shows the bar
as a dashed outline, empty. Sizes: 2px in list rows, 6px on cards, 40px at the top
of the session detail screen.

LAYOUT RULES:
- Bottom tab bar, 5 items, icon + label: Accueil, Joueurs, Séances, Classement, Stats.
- Touch targets 44px minimum, 52px for +/- counters.
- Primary action always full width at the bottom of the screen, 52-56px tall.
- Corner radius: 4px badges, 8px buttons and inputs, 14px cards.
- No drop shadows, no gradients, no glassmorphism, no glow, no illustrations,
  no photos, no football imagery, no stadium background.
- Hierarchy comes from background value steps and 1px hairlines only.

Use the exact French labels below, do not translate them.
```

---

## Les 18 écrans

### 1. Accueil

```
Screen: "Accueil" (home).
Header row: title "Statoo" in Archivo Expanded 700, and a settings gear icon on
the right, no other icons.
Card 1 "Dernière séance": date "Mar. 4 août · 20:30", a 6px score bar (4 vs 2
proportion), the score "4 — 2" in 32px Archivo Expanded with "Équipe A" and
"Équipe B" as 11px uppercase muted labels under each number, and a "5v5" badge
(1px #2A3831 outline, muted text).
Full-width primary button #FFC94F, black text: "Nouvelle séance".
Section "Top 3" with header 11px uppercase: three rows, rank number then name then
points, rank 1 number in #FFC94F, all other ranks in muted text. No medals.
Footer line, 11px uppercase muted: "Sauvegardé il y a 2 jours".
Bottom tab bar with "Accueil" active in #FFC94F.
```

### 2. Joueurs — liste

```
Screen: "Joueurs".
Header: title "Joueurs" and a "+" icon button on the right.
Search field on #1B2721, placeholder "Rechercher un joueur".
List of 7 player rows on #121B17 cards. Each row: 36px circular avatar showing
two initials on #1B2721, then name (15px) with nickname under it (13px muted),
then three right-aligned tabular numbers with 11px uppercase headers above the
first row only: "J", "PTS", "BUTS".
Names: Karim "Kaka", Yannick, Ismaël "Issa", Prosper, Adamou, Éric, Bénédicte.
Below, a collapsed section header with a chevron: "Archivés (2)".
Bottom tab bar with "Joueurs" active.
```

### 3. Joueur — création / édition

```
Screen: "Nouveau joueur", full page form with a back arrow.
Fields on #1B2721, 8px radius, 13px labels above each field:
- "Nom" (required, filled with "Karim")
- "Surnom" (optional, filled with "Kaka")
- "Photo" — a 64px circular avatar placeholder showing initials, with a small
  text button "Choisir une photo" next to it.
Below the name field, an inline warning in 13px #FFC94F text, no icon, no box:
"Un joueur porte déjà ce nom. Vous pouvez continuer."
Bottom of screen: full-width #FFC94F button "Enregistrer", and above it a
transparent button with 1px #2A3831 border: "Annuler".
```

### 4. Fiche joueur

```
Screen: player detail, back arrow in header.
Top block: 56px circular avatar with initials, name "Karim" in 20px Archivo
Expanded, nickname "Kaka" in 13px muted, and a text button "Archiver" on the right.
Summary block: a row of three big numbers in 32px Archivo Expanded with 11px
uppercase muted labels underneath — "18" / "J", "36" / "POINTS", "2,00" / "PTS/MATCH".
Second row, smaller, 15px: "11 V · 3 N · 4 D" and "61 % de victoires".
Divider hairline.
Raw stats block, header 11px uppercase "Statistiques brutes": a 2-column grid of
label/value pairs — Buts 14, Passes 9, Cartons jaunes 3, Cartons rouges 0,
Apparitions 20.
Divider hairline.
Section "Historique": 4 compact rows, each with a 2px score bar, a date, a "5v5"
badge, the score, and the player's own line "2 buts · 1 passe" in 13px muted.
```

### 5. Séances — liste

```
Screen: "Séances".
Header: title "Séances" and a "+" icon button.
A vertical list of 6 cards on #121B17, 8px radius, newest first. Each card:
a full-width 2px score bar at the very top edge of the card, then a single row
with the date on the left ("Mar. 4 août"), badges in the middle, and the score
"4 — 2" right-aligned in 18px Archivo Expanded.
Variants to show:
- row 1: normal closed session, "5v5" badge.
- row 2: closed with an extra "Amical" badge (1px outline), score "3 — 3",
  score bar split 50/50.
- row 3: closed with a 6px solid #F0503C dot before the date, score "1 — 5".
- row 4: a "Brouillon" badge, dashed empty score bar, score shown as "—" in muted.
- rows 5-6: normal closed sessions.
Bottom tab bar with "Séances" active.
```

### 6. Nouvelle séance — création

```
Screen: "Nouvelle séance", back arrow.
Section 1, header 11px uppercase "Quand": a date field "Sam. 9 août 2026" and a
time field "20:30" side by side on #1B2721.
Section 2, header 11px uppercase "Présents (8)": a grid of selectable player
chips, 2 columns, each 44px tall — avatar initials, name, and a checkbox on the
right. 8 chips selected (checkbox filled #FFC94F with a black check), 3 unselected.
Section 3, header 11px uppercase "Options": two rows with a label, a 13px muted
helper line, and a toggle switch on the right —
- "Séance classée" / "Compte pour le classement" (toggle ON, #FFC94F)
- "Effectifs inégaux autorisés" / "Permet un 6v4" (toggle OFF)
Bottom: full-width #FFC94F button "Créer la séance".
```

### 7. Séance brouillon — composition

```
Screen: session detail, DRAFT state. Back arrow, title "Mar. 4 août", a
"Brouillon" badge in the header.
Top: a dashed empty score bar, 40px tall, with "—" placeholders where the numbers
would be.
Below it, a full-width button with 1px #2A3831 border: "Tirer au sort".
Two columns separated by a 1px vertical #2A3831 hairline running the full height.
Left column header: a small solid #FFC94F pill with black uppercase text
"ÉQUIPE A", and "4 joueurs" in 11px muted under it.
Right column header: a pill with 1px #556860 outline and 45-degree hatching,
text "ÉQUIPE B", and "4 joueurs" under it.
Each column lists 4 players: 28px initials avatar, name, and a small drag/move
icon on the outer edge.
At the bottom of each column, a ghost row with a "+" and the text
"Ajouter un joueur".
Sticky bottom bar: full-width #FFC94F button "Saisir les stats".
```

### 8. Séance brouillon — saisie des stats

```
Screen: session detail, stat entry, DRAFT.
Top: score entry — two large number fields side by side on #1B2721, each 44px
tall showing "4" and "2" in 32px Archivo Expanded, with "ÉQUIPE A" and "ÉQUIPE B"
as 11px uppercase labels; the team B label carries the hatched outline pill.
Between them a large "—".
Under it, a 40px score bar filled 4 vs 2.
Then a list of players as accordion rows. One row is expanded, the rest collapsed.
Collapsed row: 28px avatar, name, and a compact summary right-aligned in 13px
muted, "2 B · 1 P".
Expanded row (Karim, in team A so its avatar has a thin #FFC94F ring): four
counter lines, each with a 13px muted label on the left and, right-aligned, a
stepper made of a 52x52 "−" button, a 44px wide number in 22px Archivo Expanded,
and a 52x52 "+" button, all on #1B2721 with 1px #2A3831 borders and 8px radius.
Labels: "Buts" (2), "Passes" (1), "Cartons jaunes" (0), "Cartons rouges" (0).
The "−" button is dimmed when the value is 0 but still visible, never hidden.
Below the player list, a block with header 11px uppercase "Buts non attribués":
two stepper lines, "Équipe A" (1) and "Équipe B" (0).
Sticky bottom bar: full-width #FFC94F button "Clôturer la séance".
```

### 9. Clôture — feuille de confirmation

```
Screen: a bottom sheet over a dimmed session detail screen. The sheet is #121B17,
14px radius on the top corners only, with a small 32px muted drag handle at the top.
Title "Clôturer la séance ?" in 20px Archivo Expanded.
A recap line, 15px: "Équipe A 4 — 2 Équipe B · 5v5 · séance classée".
A non-blocking warning box: background #260907, 1px #A22C1E border, 8px radius,
13px text, no icon and no action button inside it. Text: "Écart de buts — Équipe A :
4 marqués, 3 attribués. Vous pouvez clore quand même."
Bottom of the sheet: a transparent button with 1px #2A3831 border "Annuler", and
BELOW it a full-width solid #FFC94F button with black text "Clôturer la séance".
The primary action is the lowest element on the screen.
```

### 10. Séance close — lecture

```
Screen: session detail, CLOSED state, read-only. Back arrow, title "Mar. 4 août
· 20:30", and a "..." overflow icon on the right.
Top: a 40px score bar filled 4 vs 2, with "4" and "2" in 44px Archivo Expanded
sitting directly below the bar at each end, and "ÉQUIPE A" / "ÉQUIPE B" 11px
uppercase labels under them. No "vainqueur" label, no winner highlight, no
trophy — the bar and the numbers say it.
A meta line of badges: "5v5".
Two columns separated by a 1px hairline, same team pills as screen 7, each player
row showing name on the left and their contribution right-aligned in 13px muted:
"2 buts · 1 passe", "1 but", "—", "1 carton jaune".
Under each column a muted line: "Buts non attribués : 1".
No bottom action bar; the overflow menu holds "Rouvrir la séance" and "Supprimer".
```

### 11. Classement — onglet Points

```
Screen: "Classement".
Header: title "Classement".
Two tabs, underline style, no pills: "Points" (active, #FFC94F underline) and
"Pts/match".
A dense table, no vertical borders, 1px #2A3831 hairline between rows only.
Column headers, 11px uppercase muted, right-aligned except the first two:
"", "Joueur", "J", "V", "N", "D", "PTS", "PTS/M".
8 rows. Rank number on the left in muted, EXCEPT rank 1 which is #FFC94F — that is
the only rank treatment, no background, no medal, no icon.
Player name in Instrument Sans; all numbers in Archivo Expanded tabular. The
"PTS" column is #EAF0EC, every other number column is muted #8CA096.
The "J" column is always visible and never truncated.
The table must fit the screen width with no horizontal scrolling.
Bottom tab bar with "Classement" active.
```

### 12. Classement — onglet Pts/match

```
Same screen as 11, with the "Pts/match" tab active.
Columns: "", "Joueur", "J", "PTS/M", "PTS".
5 eligible players listed, sorted by points per match descending, rank 1 number
in #FFC94F.
Then a 1px #2A3831 divider with a 11px uppercase muted header "Sous le seuil".
Below it, 3 rows entirely in muted #8CA096, each with the player's numbers and a
13px trailing line: "il manque 3 séances", "il manque 5 séances",
"il manque 6 séances". Do not write "non éligible", do not grey them out to the
point of illegibility, do not hide them behind a "voir plus".
```

### 13. Classements secondaires

```
Screen reached from the bottom of the Classement screen: "Classements secondaires".
Three stacked blocks, each a #121B17 card with an 11px uppercase header and 5 rows:
"Meilleurs buteurs", "Meilleurs passeurs", "Cartons".
Each row: rank, avatar initials, name, and the number right-aligned in Archivo
Expanded. Rank 1 number in #FFC94F.
The "Cartons" block shows two numbers per row: a yellow count and a red count,
with 11px uppercase column headers "J" and "R", the red count in #F0503C when
above zero.
Under each card header, a 13px muted line: "Toutes séances, amicales comprises."
```

### 14. Statistiques globales

```
Screen: "Stats".
Header: title "Statistiques".
A 2-column grid of stat blocks on #121B17 cards, each with a big number in 32px
Archivo Expanded and an 11px uppercase muted label under it:
"24" SÉANCES JOUÉES · "21" DONT CLASSÉES · "11" JOUEURS ACTIFS · "13" AU TOTAL ·
"142" BUTS TOTAUX · "5,92" BUTS PAR SÉANCE · "96" PASSES · "17" CARTONS.
Below the grid, a full-width card with header "Attribution des buts": two lines,
"Buts marqués 142" and "Buts attribués 131", then a 13px muted line
"11 buts non attribués". No chart, no pie, no progress ring.
Bottom tab bar with "Stats" active.
```

### 15. Réglages

```
Screen: "Réglages", back arrow.
Grouped list, each group with an 11px uppercase muted header and rows on #121B17.
Group "Sauvegarde":
- row "Dernière sauvegarde" with a right-aligned muted value "Il y a 2 jours"
- row "Sauvegarder maintenant" with a chevron
- row "Restaurer une sauvegarde" with a chevron
Group "À propos":
- row "Version de l'app" value "1.0.0"
- row "Version du schéma" value "1"
- row "Nombre de séances" value "24"
No account section, no login, no sync toggle, no notifications — this app has none.
```

### 16. Restauration — liste des sauvegardes

```
Screen: "Restaurer une sauvegarde", back arrow.
A 13px muted intro paragraph: "La restauration efface les données locales et les
remplace par la sauvegarde choisie."
A list of 8 rows on #121B17: filename-free display — the date in 15px
("4 août 2026 · 21:04"), and under it a 13px muted line "24 séances · 48 Ko".
One row is selected, marked by a 2px #FFC94F left edge, no checkbox.
Bottom: full-width #F0503C button "Restaurer et écraser les données".
```

### 17. Restauration — confirmation destructive

```
Screen: bottom sheet over a dimmed screen, #121B17, top corners 14px radius.
Title "Restaurer cette sauvegarde ?" in 20px Archivo Expanded.
Body 15px: "Les 24 séances et 13 joueurs actuellement enregistrés seront effacés
et remplacés par la sauvegarde du 4 août 2026."
An input field on #1B2721 with a 13px label above it: "Tapez le nom du groupe pour
confirmer", placeholder "Statoo".
Bottom: transparent button with 1px border "Annuler", and BELOW it a full-width
solid #F0503C button with white text "Restaurer et écraser".
```

### 18. États vides

```
Four separate empty-state screens, same construction, no illustration, no icon,
no mascot.
Centered vertically in the content area: a 15px muted sentence, then a single
#FFC94F button below it, 220px wide, centered.
- Séances: "Aucune séance. La première prend deux minutes." + button "Nouvelle séance"
- Joueurs: "Ajoutez les joueurs du groupe pour commencer." + button "Nouveau joueur"
- Classement: "Le classement apparaîtra après la première séance close." + no button
- Sauvegardes: "Aucune sauvegarde. Elle se déclenchera à la prochaine clôture."
  + button "Sauvegarder maintenant"
Each keeps its header and its bottom tab bar.
```

---

## Écran bonus — confirmation d'écrasement de composition

À générer si tu veux couvrir le troisième cas destructif du design system.

```
Bottom sheet over a dimmed session detail. Title "Remplacer la composition
actuelle ?" in 20px Archivo Expanded. Body 15px muted: "Le tirage au sort écrase
les équipes actuelles. Les stats déjà saisies sont conservées."
Buttons: transparent "Annuler" on top, full-width solid #FFC94F "Tirer au sort"
below it.
```

---

## Contrôle qualité après génération

Vérifier sur chaque rendu :

- [ ] Aucun libellé traduit en anglais.
- [ ] Aucune médaille, coupe, étoile, flamme, badge de rareté, emoji.
- [ ] L'équipe B n'a pas reçu une couleur pleine (bleu, rouge, vert).
- [ ] Le bandeau de score est proportionnel au score, pas coupé à 50/50 par défaut.
- [ ] La colonne « J » est présente dans les deux onglets du classement.
- [ ] Aucun scroll horizontal sur le tableau de classement.
- [ ] Le bouton destructif est en bas, l'annulation au-dessus.
- [ ] Aucune ombre portée, aucun dégradé, aucun fond photo.
