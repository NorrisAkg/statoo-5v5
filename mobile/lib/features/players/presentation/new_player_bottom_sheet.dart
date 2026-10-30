import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:remixicon/remixicon.dart';

import '../../../core/media/player_photo.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/primary_button.dart';
import '../../shared/application/shared_providers.dart';
import '../../team/application/team_provider.dart';
import '../application/players_provider.dart';

class NewPlayerBottomSheet extends ConsumerStatefulWidget {
  const NewPlayerBottomSheet({super.key});

  @override
  ConsumerState<NewPlayerBottomSheet> createState() =>
      _NewPlayerBottomSheetState();
}

class _NewPlayerBottomSheetState extends ConsumerState<NewPlayerBottomSheet> {
  final _nameController = TextEditingController();
  final _nicknameController = TextEditingController();
  final _nameFocusNode = FocusNode();
  String? _photo;
  Uint8List? _imageBytes;
  final ImagePicker _picker = ImagePicker();
  String? _nameError;
  bool _submitting = false;
  late final String? _groupId = ref.read(activeTeamIdProvider);

  Future<void> _pickImage() async {
    if (!ref.read(canWriteProvider('members'))) return;
    try {
      final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
      if (image != null) {
        if (await image.length() > PlayerPhoto.maxBytes) {
          throw const FormatException(
            'Photo trop volumineuse : maximum 2 Mio.',
          );
        }
        final bytes = await image.readAsBytes();
        final photo = await PlayerPhoto.encode(bytes);
        if (!mounted) return;
        setState(() {
          _photo = photo;
          _imageBytes = bytes;
        });
      }
    } on Object catch (error) {
      if (mounted) setState(() => _nameError = 'Photo non ajoutée : $error');
    }
  }

  void _clearForm() {
    _nameController.clear();
    _nicknameController.clear();
    setState(() {
      _photo = null;
      _imageBytes = null;
      _nameError = null;
    });
    _nameFocusNode.requestFocus();
  }

  Future<void> _submit({required bool createAnother}) async {
    if (_submitting) return;
    final group = _groupId;
    final name = _nameController.text.trim();
    if (name.isEmpty) return;
    setState(() => _submitting = true);
    try {
      final taken = await ref
          .read(playersListProvider.notifier)
          .isNameTaken(name);
      if (!mounted) return;
      if (group != ref.read(activeTeamIdProvider)) {
        throw StateError(
          'Le groupe actif a changé. Rouvrez le formulaire dans le bon groupe.',
        );
      }
      if (taken) {
        setState(
          () => _nameError =
              'Un joueur nommé « $name » existe déjà. Modifiez légèrement le nom.',
        );
        return;
      }

      await ref
          .read(playersListProvider.notifier)
          .addPlayer(
            name: name,
            nickname: _nicknameController.text.trim().isNotEmpty
                ? _nicknameController.text.trim()
                : null,
            avatarUrl: _photo,
          );

      if (mounted) {
        if (createAnother) {
          _clearForm();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Joueur ajouté avec succès !')),
          );
        } else {
          Navigator.pop(context);
        }
      }
    } on Object catch (error) {
      if (mounted) setState(() => _nameError = 'Ajout impossible : $error');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _nicknameController.dispose();
    _nameFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final keyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;
    final writable = ref.watch(canWriteProvider('members'));
    final isFormValid =
        writable && !_submitting && _nameController.text.trim().isNotEmpty;
    // Capturer le groupe dès l'ouverture, avant tout changement de contexte.
    final _ = _groupId;

    return Container(
      decoration: BoxDecoration(
        color: context.colors.background950,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 12,
        bottom:
            MediaQuery.of(context).viewInsets.bottom + (keyboardOpen ? 12 : 24),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!writable)
              const Text(
                'Consultation uniquement. Le rôle ADMIN est requis pour gérer les joueurs.',
              ),
            Center(
              child: Container(
                width: 48,
                height: 4,
                decoration: BoxDecoration(
                  color: context.colors.background700,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            SizedBox(height: keyboardOpen ? 8 : 24),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Nouveau joueur',
                    style: Theme.of(context).textTheme.headlineSmall
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
                if (keyboardOpen)
                  IconButton(
                    tooltip: 'Masquer le clavier',
                    onPressed: () =>
                        FocusManager.instance.primaryFocus?.unfocus(),
                    icon: const Icon(Remix.keyboard_line),
                  ),
              ],
            ),
            SizedBox(height: keyboardOpen ? 8 : 24),
            Center(
              child: GestureDetector(
                onTap: _pickImage,
                child: CircleAvatar(
                  radius: keyboardOpen ? 24 : 48,
                  backgroundColor: context.colors.background800,
                  backgroundImage: _imageBytes != null
                      ? MemoryImage(_imageBytes!)
                      : null,
                  child: _imageBytes == null
                      ? Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Remix.camera_lens_line,
                              size: 28,
                              color: context.colors.foreground500,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Photo',
                              style: TextStyle(
                                color: context.colors.foreground500,
                                fontSize: 10,
                              ),
                            ),
                          ],
                        )
                      : null,
                ),
              ),
            ),
            SizedBox(height: keyboardOpen ? 8 : 24),
            Text(
              'Nom *',
              style: TextStyle(
                color: context.colors.foreground300,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              enabled: writable && !_submitting,
              controller: _nameController,
              focusNode: _nameFocusNode,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(
                hintText: 'Karim Benali',
                hintStyle: TextStyle(color: context.colors.foreground600),
                filled: true,
                fillColor: context.colors.background900,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: context.colors.background700),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: context.colors.background700),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: context.colors.primary500),
                ),
              ),
              onChanged: (_) => setState(() => _nameError = null),
            ),
            if (_nameError != null) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  Icon(
                    Remix.error_warning_line,
                    size: 14,
                    color: Theme.of(context).colorScheme.error,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      _nameError!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 16),
            Text(
              'Surnom',
              style: TextStyle(
                color: context.colors.foreground300,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              enabled: writable && !_submitting,
              controller: _nicknameController,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) {
                if (isFormValid) {
                  unawaited(_submit(createAnother: true));
                }
              },
              decoration: InputDecoration(
                hintText: 'Kaka',
                hintStyle: TextStyle(color: context.colors.foreground600),
                filled: true,
                fillColor: context.colors.background900,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: context.colors.background700),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: context.colors.background700),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: context.colors.primary500),
                ),
              ),
            ),
            if (!keyboardOpen) ...[
              const SizedBox(height: 16),
              Text(
                "Sans photo, l'avatar affiche les initiales sur une couleur dérivée du nom.",
                style: TextStyle(
                  color: context.colors.foreground500,
                  fontSize: 14,
                ),
              ),
            ],
            SizedBox(height: keyboardOpen ? 8 : 32),
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: context.colors.foreground50,
                      side: BorderSide(color: context.colors.background700),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(9999),
                      ),
                    ),
                    child: const Text(
                      'Annuler',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: OutlinedButton(
                    onPressed: isFormValid
                        ? () => _submit(createAnother: true)
                        : null,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: context.colors.primary500,
                      side: BorderSide(
                        color: isFormValid
                            ? context.colors.primary500
                            : context.colors.background700,
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(9999),
                      ),
                    ),
                    child: Icon(
                      Remix.add_line,
                      color: isFormValid
                          ? context.colors.primary500
                          : context.colors.foreground600,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 4,
                  child: PrimaryButton(
                    label: _submitting ? 'Création…' : 'Créer',
                    onPressed: isFormValid
                        ? () => _submit(createAnother: false)
                        : null,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
