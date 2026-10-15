import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:remixicon/remixicon.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/primary_button.dart';
import '../application/players_provider.dart';

class NewPlayerBottomSheet extends ConsumerStatefulWidget {
  const NewPlayerBottomSheet({super.key});

  @override
  ConsumerState<NewPlayerBottomSheet> createState() => _NewPlayerBottomSheetState();
}

class _NewPlayerBottomSheetState extends ConsumerState<NewPlayerBottomSheet> {
  final _nameController = TextEditingController();
  final _nicknameController = TextEditingController();
  final _nameFocusNode = FocusNode();
  File? _imageFile;
  final ImagePicker _picker = ImagePicker();
  String? _nameError;

  Future<void> _pickImage() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() {
        _imageFile = File(image.path);
      });
    }
  }

  void _clearForm() {
    _nameController.clear();
    _nicknameController.clear();
    setState(() {
      _imageFile = null;
      _nameError = null;
    });
    _nameFocusNode.requestFocus();
  }

  Future<void> _submit({required bool createAnother}) async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;

    final taken = await ref.read(playersListProvider.notifier).isNameTaken(name);
    if (taken) {
      setState(() => _nameError = 'Un joueur nommé « $name » existe déjà. Modifiez légèrement le nom.');
      return;
    }

    await ref.read(playersListProvider.notifier).addPlayer(
      name: name,
      nickname: _nicknameController.text.trim().isNotEmpty
          ? _nicknameController.text.trim()
          : null,
      avatarUrl: _imageFile?.path,
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
    final isFormValid = _nameController.text.trim().isNotEmpty && _nameError == null;

    return Container(
      decoration: BoxDecoration(
        color: context.colors.background950,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 12,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
            const SizedBox(height: 24),
            Text(
              'Nouveau joueur',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            Center(
              child: GestureDetector(
                onTap: _pickImage,
                child: CircleAvatar(
                  radius: 48,
                  backgroundColor: context.colors.background800,
                  backgroundImage: _imageFile != null ? FileImage(_imageFile!) : null,
                  child: _imageFile == null
                      ? Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Remix.camera_lens_line, size: 28, color: context.colors.foreground500),
                            const SizedBox(height: 4),
                            Text('Photo', style: TextStyle(color: context.colors.foreground500, fontSize: 10)),
                          ],
                        )
                      : null,
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text('Nom *', style: TextStyle(color: context.colors.foreground300, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            TextField(
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
                  Icon(Remix.error_warning_line, size: 14, color: Theme.of(context).colorScheme.error),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      _nameError!,
                      style: TextStyle(color: Theme.of(context).colorScheme.error, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 16),
            Text('Surnom', style: TextStyle(color: context.colors.foreground300, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            TextField(
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
            const SizedBox(height: 16),
            Text(
              "Sans photo, l'avatar affiche les initiales sur une couleur dérivée du nom.",
              style: TextStyle(color: context.colors.foreground500, fontSize: 14),
            ),
            const SizedBox(height: 32),
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
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9999)),
                    ),
                    child: const Text('Annuler', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: OutlinedButton(
                    onPressed: isFormValid ? () => _submit(createAnother: true) : null,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: context.colors.primary500,
                      side: BorderSide(color: isFormValid ? context.colors.primary500 : context.colors.background700),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9999)),
                    ),
                    child: Icon(Remix.add_line, color: isFormValid ? context.colors.primary500 : context.colors.foreground600),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 4,
                  child: PrimaryButton(
                    label: 'Créer',
                    onPressed: isFormValid ? () => _submit(createAnother: false) : null,
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
