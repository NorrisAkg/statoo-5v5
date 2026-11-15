import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Champ précédé d'un libellé visible permanent, qui nomme aussi le champ pour les
/// lecteurs d'écran (A11Y-004).
///
/// Le libellé est un texte ordinaire au-dessus du champ : il passe à la ligne au lieu
/// d'être coupé, même à 320 dp avec un texte à 200 %, ce qu'un libellé flottant
/// d'`InputDecoration` (une seule ligne) ne garantit pas. Style des libellés de
/// formulaire de `create_team_screen.dart`.
class LabeledField extends StatelessWidget {
  const LabeledField({
    required this.label,
    required this.child,
    this.semanticLabel,
    super.key,
  });

  /// Libellé affiché.
  final String label;

  /// Nom annoncé, si différent du libellé (par exemple « (obligatoire) » pour « * »).
  final String? semanticLabel;

  /// Le champ de saisie.
  final Widget child;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    mainAxisSize: MainAxisSize.min,
    children: [
      // Le nom est porté par le champ : le libellé n'est pas lu une seconde fois.
      ExcludeSemantics(
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: context.colors.foreground200,
          ),
        ),
      ),
      const SizedBox(height: 6),
      Semantics(label: semanticLabel ?? label, child: child),
    ],
  );
}
