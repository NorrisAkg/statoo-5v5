# Logo transparent — scénarios avant modification

- LOGO-01 : l'en-tête charge une image PNG avec canal alpha ; le fond est réellement transparent et le dessin/texte du logo existant sont conservés.
- LOGO-02 : le CSS de l'image n'ajoute aucun aplat blanc ; contrôle sur les thèmes sombre et clair.
- LOGO-03 : la nouvelle ressource est incluse dans le shell hors connexion et le build ; le logo original reste intact.
- LOGO-04 : l'en-tête conserve ses dimensions et ne déborde pas sur mobile et desktop.

Outil : image_gen intégré, compétence imagegen.
Prompt final : "Create a clean transparent PNG cutout of ONLY the existing upper emblem in this reference logo: its navy and neon green football hexagon, upward arrow and bars. Preserve this exact existing emblem design and colors. Exclude the lettering underneath; the website already renders the brand name separately beside this emblem. No white background, no wordmark, no shadows, no glow. Center the emblem in a square canvas, with minimal transparent padding (about 5%). True alpha transparency. Do not invent a new logo; use the supplied emblem faithfully."

Les deux premiers détourages complets ont été écartés à cause d'artefacts dans les lettres. La version retenue utilise l'emblème seul, avec le nom HTML conservé à côté. Le même PNG transparent sert de favicon. L'original natif reste intact.

Résultats : RED constaté sur l'ancienne image ; 36 tests unitaires web et les deux tests navigateur desktop/mobile réussis, build web réussi. PNG avec alpha vérifié, coin transparent (0), centre quasiment opaque (254/255). Le fond CSS blanc est supprimé. Asset : web/icons/logo-transparent.png, image_gen intégré. Aucun changement du logo natif.
