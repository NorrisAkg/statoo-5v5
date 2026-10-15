# Accès collectif des membres — 15 octobre 2026

Scénarios écrits avant le code applicatif.

Décision : les simples membres utilisent l'accès collectif de consultation. Les nouveaux comptes individuels nécessitent au moins un rôle de responsable (Admin, Président, Vice-président, Trésorier, adjoint, SG, adjoint ou Censeur). MEMBER reste le rôle de base automatique de tous les comptes.

Les comptes existants et l'historique sont conservés. Un transfert peut laisser l'ancien titulaire sans responsabilité : il conserve alors son accès de consultation existant. Aucune suppression ou migration automatique des accès n'est incluse.

| ID | Scénario | Résultat attendu |
| --- | --- | --- |
| CPT-01 | Création avec liste de rôles vide ou MEMBER seul | Refus 422 explicite ; aucun compte ajouté. |
| CPT-02 | Création avec un rôle de responsable, dont Censeur | Compte créé, associé au membre, MEMBER ajouté. |
| CPT-03 | Rôle inconnu, en double ou déjà attribué | Validations existantes conservées. |
| CPT-04 | Accès collectif | Connexion et consultation conservées ; écritures et création de compte interdites. |
| CPT-05 | Ancien titulaire perdant son dernier rôle par transfert | Transfert possible, compte conservé et en lecture seule ; historique préservé. |
| CPT-06 | Dialogue mobile sans membre ou sans responsabilité | Création désactivée, règle expliquée. |
| CPT-07 | Membre et responsabilité sélectionnés puis dernière responsabilité décochée | Création activée puis désactivée. |
| CPT-08 | Écran de gestion et accès membres | Mention explicite de l'accès collectif ; actions Admin et contrôles de droits existants conservés. |

Vérifier le backend et les tests mobile du groupe partagé ; aucune validation sur appareil annoncée sans exécution.

## Résultats observés

- RED backend : 2 échecs comportementaux (créations sans responsabilité acceptées au lieu d'être refusées), 12 tests ciblés déjà réussis.
- RED mobile : absence de l'explication sur l'accès collectif constatée avant modification applicative mobile.
- GREEN mobile : 18 tests réussis (`shared_group_screen_test.dart` et `write_capabilities_test.dart`). La fixture charge explicitement les membres avant d'ouvrir le dialogue.
- GREEN backend : suite complète `backend/tests`, 38 tests réussis, dont refus sans responsabilité, comptes responsables, transfert et consultation collective.
- Portail : le test de classement web passe ; aucun changement d'authentification nécessaire pour l'accès collectif.
- Aucun contrôle sur téléphone ni déploiement effectué.
