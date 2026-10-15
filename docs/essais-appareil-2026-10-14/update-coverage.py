"""Ajoute les preuves appareil sans remplacer la couverture automatique antérieure."""
import csv
from pathlib import Path

root = Path(__file__).resolve().parents[1]
p = root / "tdd-majeurs-ui-ux-couverture.csv"
with p.open(encoding="utf-8-sig", newline="") as f:
    reader = csv.DictReader(f)
    columns = list(reader.fieldnames)
    rows = list(reader)
evidence = {
    "UX01-01": ("Partiel", "12-import-recap", "Appareil vide uniquement ; pas deux groupes déjà présents."),
    "UX01-06": ("Partiel", "12-import-recap ; 15-qa-reprise-restauree", "Import confirmé ; reprise nécessaire pour constater accueil ; unicité transactionnelle non instrumentée."),
    "UX01-07": ("Confirmé sur le cas testé", "12-import-recap", "Aucun groupe local ; deux groupes entrants et comptages affichés."),
    "UX02-01": ("Confirmé sur le cas testé", "31-apres-abandon ; 32-retour-propre", "Retour sans dialogue depuis le point inchangé."),
    "UX02-02": ("Partiel", "22-finance-modifiee ; 26-garde-retour", "Une cotisation à 5 F ; pas trois cotisations."),
    "UX02-03": ("Partiel", "28-garde-android ; 29-garde-android-sans-clavier", "Retour Android par keyevent ; geste prédictif non testé."),
    "UX02-04": ("Partiel", "27-saisie-conservee", "Continuer conserve la cotisation ; dépenses et fermeture extérieure non testées."),
    "UX02-05": ("Partiel", "30-abandon-explicite ; 31-apres-abandon", "Retour au total 0 F après abandon de 5 F ; pas de comparaison exhaustive DB."),
    "UX03-01": ("Confirmé sur le cas testé", "87-seance-test-1 ; 94-seconde-seance ; preuves-filtres.json", "Deux créations UI le 15/10 ; références -1/-2 et alias distincts contrôlés dans SQLite. Pas de paiements enregistrés."),
    "UX04-01": ("Confirmé sur le cas testé", "69-conflit-bas-version ; 71-conflit-motif", "Versements identiques ; Terrain 30 F et Eau 80 F distingués."),
    "UX04-09": ("Confirmé sur le cas testé", "68-comparaison-conflit ; 69-conflit-bas-version", "Trésorier et vice, avec horodatage, affichés."),
    "UX04-13": ("Partiel — réserve D03", "72-conflit-validation-vide", "Motif vide garde le dialogue ; message non visible dans la zone capturée ; espaces seuls non testés."),
    "UX04-15": ("Partiel", "74-conflit-decision ; preuves-filtres.json", "Version publiée conservée, révision 2, motif Controle-QA au journal ; unicité requête non instrumentée."),
    "UX05-01": ("Partiel", "61-recap-depart", "Relecture visible avant POST d’approbation ; aucun autre cas de données."),
    "UX05-02": ("Partiel", "61-recap-depart", "Caisse, date, avance et dettes contrôlées pour deux membres renseignés."),
    "UX05-03": ("Partiel", "61-recap-depart", "Auteur et date disponibles ; absence non testée."),
    "UX05-05": ("Partiel", "61-recap-depart ; 62-approbation-perimee ; preuves-filtres.json", "Approbation normale réussie ; capture 62 mal nommée, pas de proposition périmée."),
    "UX05-06": ("Non validé — montage interrompu", "rapport.md", "Modification concurrente non exécutée ; ne pas compter le test 409 comme réussi sur appareil."),
    "UX05-13": ("Partiel", "62-approbation-perimee ; 63-sync-apres-approbation", "POST approuvé, import local refusé par collision des identifiants fictifs ; message distingue les deux issues."),
    "UX06-01": ("Partiel", "76-pdt-accueil ; 77-pdt-joueurs", "Président seul sans création sportive ou de membre ; pas toute la matrice."),
    "UX06-03": ("Partiel", "81-sg-accueil ; 83-sg-composition ; 87-seance-test-1 ; 88-sg-retardataires", "SG combiné PDT ; sport créé, aucune création de membre dans la feuille retardataires ; SGA non testé."),
    "UX06-09": ("Partiel", "76-pdt-accueil ; 81-sg-accueil ; role-sport-test.json", "Attribution SG visible après reprise/synchronisation ; révocation et réaction sans reprise non vérifiées."),
    "UX07-01": ("Confirmé sur le cas testé", "16-liste-tournois ; 17-detail-tournoi", "Tournoi 3/1/0 CLOSED A et scores nuls conservé après import."),
    "UX07-02": ("Partiel", "16-liste-tournois", "DRAW_ALL 2/2/2 seulement pour les autres résultats."),
    "UX07-09": ("Partiel", "17-detail-tournoi", "Noms et joueurs A/B/C consultés ; comparaison de toutes statistiques non faite."),
    "UX07-15": ("Partiel — réserve D01", "15-qa-reprise-restauree ; 16-liste-tournois ; 17-detail-tournoi", "Classement, liste et détail cohérents ; résumé accueil A-B 0-0 erroné."),
    "UX08-01": ("Partiel visuel", "35-parametres ; 61-recap-depart", "Rendu clair observé ; ratios chiffrés issus des tests automatisés."),
    "UX08-02": ("Partiel visuel", "45-theme-sombre ; 49-accueil-bas", "Rendu sombre observé ; pas de mesure optique de contraste."),
    "UX08-05": ("Partiel visuel", "16-liste-tournois ; 77-pdt-joueurs", "Sous-titre Séances clair et Joueurs sombre ; pas toutes combinaisons."),
    "UX08-09": ("Partiel visuel", "17-detail-tournoi ; 35-parametres ; 82-sg-nouvelle-seance", "Icônes standard observées ; seuil optique non mesuré."),
    "UX08-11": ("Partiel", "44-theme-menu ; 45-theme-sombre ; 49-accueil-bas", "Bascule système clair vers sombre observée dans réglages puis accueil."),
    "UX08-12": ("Échec sur le cas testé — couverture partielle", "95-detail-texte-200 ; preuves-filtres.json", "Détail en brouillon à 200 % : RenderFlex overflow 237 pixels sur Composition & Équipes ; autres écrans et 100/130 % non testés ; 0.9 restauré."),
    "UX08-14": ("Partiel visuel", "35-parametres ; 45-theme-sombre", "Portrait clair/sombre uniquement ; ni forte lumière ni TalkBack parlé."),
}
for name in ["AppareilStatut", "PreuveAppareil", "LimiteAppareil"]:
    if name not in columns:
        columns.append(name)
for row in rows:
    status, proof, note = evidence.get(row["Id"], ("Non exécuté sur appareil", "", ""))
    row.update(AppareilStatut=status, PreuveAppareil=proof, LimiteAppareil=note)
with p.open("w", encoding="utf-8-sig", newline="") as f:
    writer = csv.DictWriter(f, fieldnames=columns)
    writer.writeheader()
    writer.writerows(rows)
print(f"{len(rows)} scénarios conservés ; {sum(r['Id'] in evidence for r in rows)} lignes annotées avec résultat ou limite appareil.")
