import 'dart:convert';
import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// Turns a picked picture into a small JPEG `data:` URL that fits in a
/// Firestore document (Cloud Storage needs the paid plan).
String? photoDataUrl(Uint8List bytes) {
  final decoded = img.decodeImage(bytes);
  if (decoded == null) return null;
  final resized = decoded.width > 480
      ? img.copyResize(decoded, width: 480)
      : decoded;
  final jpg = img.encodeJpg(resized, quality: 70);
  if (jpg.length > 500000) return null;
  return 'data:image/jpeg;base64,${base64Encode(jpg)}';
}
