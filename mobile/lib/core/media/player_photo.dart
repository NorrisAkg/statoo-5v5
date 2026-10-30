import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as image;

/// Shared bounds and encoding for selected, exported and restored portraits.
abstract final class PlayerPhoto {
  static const int maxBytes = 2 * 1024 * 1024;
  static const int maxBackupBytes = 32 * 1024 * 1024;
  static const maxPixels = 16000000;

  static bool isRemote(String source) {
    final uri = Uri.tryParse(source);
    return uri != null &&
        (uri.scheme == 'http' || uri.scheme == 'https') &&
        uri.host.isNotEmpty;
  }

  static String _mime(Uint8List bytes) {
    if (bytes.length >= 8 &&
        bytes[0] == 137 &&
        bytes[1] == 80 &&
        bytes[2] == 78 &&
        bytes[3] == 71) {
      return 'image/png';
    }
    if (bytes.length >= 3 &&
        bytes[0] == 255 &&
        bytes[1] == 216 &&
        bytes[2] == 255) {
      return 'image/jpeg';
    }
    if (bytes.length >= 12 &&
        ascii.decode(bytes.sublist(0, 4), allowInvalid: true) == 'RIFF' &&
        ascii.decode(bytes.sublist(8, 12), allowInvalid: true) == 'WEBP') {
      return 'image/webp';
    }
    throw const FormatException(
      'Photo illisible : choisissez une image PNG, JPEG ou WebP.',
    );
  }

  static Future<String> encode(Uint8List bytes) async {
    if (bytes.length > maxBytes) {
      throw const FormatException('Photo trop volumineuse : maximum 2 Mio.');
    }
    final mime = _mime(bytes);
    ui.Codec? codec;
    try {
      // Read headers before decoding pixels. ImageDescriptor dimensions are
      // unavailable in Flutter web; the same bounds must apply on both clients.
      final int width;
      final int height;
      if (mime == 'image/png') {
        if (bytes.length < 24) {
          throw const FormatException('Photo PNG incomplète.');
        }
        final header = ByteData.sublistView(bytes);
        width = header.getUint32(16);
        height = header.getUint32(20);
      } else {
        final image.Decoder decoder = mime == 'image/jpeg'
            ? image.JpegDecoder()
            : image.WebPDecoder();
        final info = decoder.startDecode(bytes);
        if (info == null) {
          throw const FormatException('En-tête de photo invalide.');
        }
        width = info.width;
        height = info.height;
      }
      if (width < 1 ||
          height < 1 ||
          width > 4096 ||
          height > 4096 ||
          width * height > maxPixels) {
        throw const FormatException(
          'Photo trop grande : maximum 4096 pixels par côté et 16 millions de pixels.',
        );
      }
      final ratio = math.max(width, height) / 128;
      codec = await ui.instantiateImageCodec(
        bytes,
        targetWidth: (width / ratio).round().clamp(1, 128),
        targetHeight: (height / ratio).round().clamp(1, 128),
        allowUpscaling: false,
      );
      final frame = await codec.getNextFrame();
      frame.image.dispose();
    } on FormatException {
      rethrow;
    } on Object {
      throw const FormatException(
        'Photo illisible : choisissez une autre image.',
      );
    } finally {
      codec?.dispose();
    }
    return 'data:$mime;base64,${base64Encode(bytes)}';
  }

  static Future<Uint8List> decode(String source) async {
    if (source.length > ((maxBytes + 2) ~/ 3) * 4 + 32) {
      throw const FormatException('Photo trop volumineuse : maximum 2 Mio.');
    }
    final match = RegExp(
      r'^data:(image/(?:png|jpeg|webp));base64,([A-Za-z0-9+/=]+)$',
    ).firstMatch(source);
    if (match == null) throw const FormatException('Photo intégrée invalide.');
    final bytes = base64Decode(match[2]!);
    if (_mime(bytes) != match[1]) {
      throw const FormatException(
        'Le type de la photo ne correspond pas à son contenu.',
      );
    }
    await encode(bytes);
    return bytes;
  }

  static Future<Uint8List> readLocal(String source) async {
    if (kIsWeb) {
      throw const FormatException(
        'Photo locale indisponible dans ce navigateur.',
      );
    }
    try {
      final file = source.startsWith('file:')
          ? File.fromUri(Uri.parse(source))
          : File(source);
      if (await file.length() > maxBytes) {
        throw const FormatException('Photo trop volumineuse : maximum 2 Mio.');
      }
      final builder = BytesBuilder(copy: false);
      await file.openRead(0, maxBytes + 1).forEach(builder.add);
      final bytes = builder.takeBytes();
      await encode(bytes);
      return bytes;
    } on FormatException {
      rethrow;
    } on Object {
      throw const FormatException(
        'Photo locale introuvable ou inaccessible. Ajoutez de nouveau la photo avant de sauvegarder.',
      );
    }
  }

  static Future<List<Map<String, dynamic>>> prepareRows(
    List<Map<String, dynamic>> players, {
    required bool importing,
  }) async {
    var total = 0;
    final rows = <Map<String, dynamic>>[];
    for (final row in players) {
      final raw = row['avatar_url'];
      if (raw != null && raw is! String) {
        throw const FormatException('Référence de photo invalide.');
      }
      final source = raw as String?;
      String? photo = source;
      if (source != null && source.isNotEmpty && !isRemote(source)) {
        if (importing && !source.startsWith('data:')) {
          // An imported path is untrusted and belongs to another device.
          photo = null;
        } else {
          final bytes = source.startsWith('data:')
              ? await decode(source)
              : await readLocal(source);
          total += bytes.length;
          if (total > maxBackupBytes) {
            throw const FormatException(
              'Les photos de la sauvegarde dépassent la limite de 32 Mio.',
            );
          }
          photo = source.startsWith('data:') ? source : await encode(bytes);
        }
      }
      rows.add({
        ...row,
        if (row.containsKey('avatar_url')) 'avatar_url': photo,
      });
    }
    return rows;
  }
}
