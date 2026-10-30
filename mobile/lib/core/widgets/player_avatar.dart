import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../media/player_photo.dart';
import 'initial_avatar.dart';

/// Decorative portrait: the adjacent player name supplies its accessible label.
class PlayerAvatar extends StatefulWidget {
  const PlayerAvatar({
    required this.source,
    required this.initial,
    required this.baseColor,
    this.size = 32,
    this.backgroundColor,
    super.key,
  });
  final String? source;
  final String initial;
  final Color baseColor;
  final double size;
  final Color? backgroundColor;

  @override
  State<PlayerAvatar> createState() => _PlayerAvatarState();
}

class _PlayerAvatarState extends State<PlayerAvatar> {
  Future<Uint8List>? _bytes;
  void _load() {
    final source = widget.source;
    _bytes = source == null || source.isEmpty || PlayerPhoto.isRemote(source)
        ? null
        : source.startsWith('data:')
        ? PlayerPhoto.decode(source)
        : PlayerPhoto.readLocal(source);
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(PlayerAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.source != widget.source) _load();
  }

  @override
  Widget build(BuildContext context) {
    final fallback = widget.backgroundColor == null
        ? InitialAvatar(
            initial: widget.initial,
            baseColor: widget.baseColor,
            size: widget.size,
          )
        : CircleAvatar(
            backgroundColor: widget.backgroundColor,
            child: Text(
              widget.initial.toUpperCase(),
              style: TextStyle(
                color: widget.baseColor,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          );
    final source = widget.source;
    Widget child = fallback;
    if (source != null && PlayerPhoto.isRemote(source)) {
      child = Image.network(
        source,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => fallback,
      );
    } else if (_bytes != null) {
      child = FutureBuilder<Uint8List>(
        future: _bytes,
        builder: (context, snapshot) =>
            snapshot.connectionState == ConnectionState.done && snapshot.hasData
            ? Image.memory(
                snapshot.data!,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => fallback,
              )
            : fallback,
      );
    }
    return ExcludeSemantics(
      child: SizedBox.square(
        dimension: widget.size,
        child: ClipOval(child: child),
      ),
    );
  }
}
