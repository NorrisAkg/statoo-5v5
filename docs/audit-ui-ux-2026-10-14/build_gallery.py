from pathlib import Path
import html, json
OUT=Path(__file__).resolve().parent

panels=[
 ('UX08 · Retour peu visible','47-end-home.png',[(3,5,10,5,'7')], '7 — La flèche retour de Nouveau groupe est blanche sur le fond gris clair. Le thème global conserve une iconTheme pour en-tête vert/sombre, même quand cette page utilise une barre transparente.'),
 ('UX08 · Sous-titre peu lisible','06-players.png',[(3,10,78,3,'1')], '1 — Nom du groupe et nombre d’actifs : #475569 sur #15803D, contraste calculé 1,51:1. La couleur sur en-tête doit être dédiée.'),
 ('UX08 · Action principale','13-state.png',[(3,34,94,7,'2')], '2 — Bouton vert, texte sombre fixe : 3,83:1 dans le code pour le thème clair. Vérifier séparément les variantes de boutons qui utilisent background950.'),
 ('UX13 · Camp dans le détail','02-open.png',[(5,17,88,18,'3')], '3 — Capture initiale : A orange et B verte. Comparer à la carte d’accueil suivante. Ce détail a été capturé avant la mise à jour de l’APK pendant l’audit.'),
 ('UX13 · Même séance dans l’accueil','03-sessions.png',[(17,18,65,5,'4')], '4 — Même date et même score : A bleue, B orange. Le code d’accueil ignore la personnalisation de la séance ; revalider la combinaison sur le dernier APK.'),
 ('UX17 · Tournoi web','web-01-tournament.png',[], 'La carte présente Les Bleus et Les Oranges ; le nom Les Verts manque alors que trois nombres de victoires sont affichés. Données entièrement fictives.'),
 ('UX16 · Session expirée','web-04-expired.png',[], 'Le tableau reste visible avec ses anciennes valeurs ; le message Connexion expirée apparaît après les points financiers. Réponse 401 simulée localement.'),
 ('UX18 · Sauvegarde','27-home-lower.png',[(15,87,72,4,'5')], '5 — La constante « Aucune sauvegarde cloud » ne mesure aucun état cloud. Le lien conduit aux réglages, dont le flux disponible est un export manuel.'),
 ('UX19 · Lien sans destination','28-finances.png',[(4,91,91,6,'6')], '6 — Capture réellement prise dans Réglages malgré son nom technique. Mentions légales a un onTap vide dans le code.'),
 ('Point fort · Abandon explicite','26-abandon.png',[], 'Confirmation vue après sélection et tirage temporaires. La création a été abandonnée sans enregistrer de séance. Ce mécanisme est à étendre au point financier.'),
 ('Couverture · Nouveau joueur et clavier','15-new-player.png',[], 'Formulaire ouvert, boutons visibles dans cette configuration. Aucun joueur n’a été créé ; les hints visibles ne sont pas des valeurs saisies.'),
 ('Couverture · Composition temporaire','25-composition-draw.png',[], 'Sélection des 16 présents, tirage 8/8 et apparition de la personnalisation. Aucun enregistrement.'),
 ('Couverture · Web 320 px','web-06-320.png',[], 'À 320 px, pas de débordement horizontal global mesuré ; le tableau conserve un défilement interne. Cela ne remplace pas une vérification à 200/400 % de zoom.'),
]
css='''body{margin:0;background:#f3f5f8;color:#172234;font:16px/1.6 system-ui,sans-serif}header,main{max-width:1250px;margin:auto;padding:28px}header{border-bottom:1px solid #cbd5e1}h1{line-height:1.15;font-size:32px}h2{font-size:19px;margin:0 0 16px}p{max-width:85ch}a{color:#125b3c}.grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(310px,1fr));gap:24px}.panel{background:white;border:1px solid #d6dde6;border-radius:16px;padding:20px}.image{position:relative;max-width:390px;margin:auto;line-height:0}.image img{width:100%;height:auto;display:block}.mark{position:absolute;box-sizing:border-box;border:3px solid #d00024;background:#ff002911}.mark b{position:absolute;top:-17px;left:-15px;background:#d00024;color:white;line-height:28px;width:28px;text-align:center;border-radius:50%;font-size:15px}.caption{font-size:14px;color:#334155}.tag{display:inline-block;background:#e2e8f0;padding:2px 9px;border-radius:6px;font-size:13px}footer{padding:24px;text-align:center}@media print{.grid{display:block}.panel{break-inside:avoid;margin-bottom:20px}.image{max-width:250px}}'''
result=['<!doctype html><html lang="fr"><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1"><title>Statoo — preuves annotées de l’audit</title><style>'+css+'</style><header><span class="tag">Audit du 14 octobre 2026</span><h1>Preuves UI/UX — Statoo</h1><p>Annotations de l’audit superposées en CSS. Les fichiers PNG originaux sont conservés sans retouche. Les captures mobiles ne prouvent que l’état et la version observés ; les constats de code et les scénarios non exécutés sont détaillés dans le rapport.</p><p><a href="rapport.html">Rapport complet</a> · <a href="couverture.csv">Matrice de couverture</a> · <a href="constats.json">Constats structurés</a></p></header><main><div class="grid">']
for title,file,marks,caption in panels:
    if not (OUT/file).exists(): continue
    result.append('<article class="panel"><h2>'+html.escape(title)+'</h2><div class="image"><img loading="lazy" src="'+file+'" alt="'+html.escape(title)+'">')
    for x,y,w,h,n in marks:
        result.append(f'<span aria-hidden="true" class="mark" style="left:{x}%;top:{y}%;width:{w}%;height:{h}%"><b>{n}</b></span>')
    result.append('</div><p class="caption">'+html.escape(caption)+'</p><a href="'+file+'">Ouvrir l’original</a></article>')
result.append('</div></main><footer>Aucune modification applicative réalisée par cet audit. Les données web sont fictives.</footer></html>')
(OUT/'preuves.html').write_text(''.join(result),encoding='utf-8')
print('Galerie créée :', len(panels),'planches')
