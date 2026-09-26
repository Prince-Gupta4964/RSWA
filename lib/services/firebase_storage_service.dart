import 'dart:io';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';

class FirebaseStorageService {
  static final FirebaseStorage _storage = FirebaseStorage.instance;

  /// Uploads a file to Firebase Storage and returns the download URL.
  /// [file] can be [File], [XFile], or [PlatformFile].
  /// [path] is the destination path in Storage (e.g., 'projects/img1.jpg').
  static Future<String?> uploadFile(dynamic file, String path) async {
    try {
      Reference ref = _storage.ref().child(path);
      UploadTask uploadTask;

      if (kIsWeb) {
        // Web handling
        Uint8List bytes;
        if (file is XFile) {
          bytes = await file.readAsBytes();
        } else if (file is PlatformFile) {
          bytes = file.bytes!;
        } else {
          throw Exception("Unsupported file type for web upload");
        }
        
        final metadata = SettableMetadata(
          contentType: _guessMimeType(path),
        );
        uploadTask = ref.putData(bytes, metadata);
      } else {
        // Mobile handling
        File fileToUpload;
        if (file is File) {
          fileToUpload = file;
        } else if (file is XFile) {
          fileToUpload = File(file.path);
        } else if (file is PlatformFile) {
          fileToUpload = File(file.path!);
        } else {
          throw Exception("Unsupported file type for mobile upload");
        }
        
        uploadTask = ref.putFile(fileToUpload);
      }

      TaskSnapshot snapshot = await uploadTask;
      return await snapshot.ref.getDownloadURL();
    } catch (e) {
      debugPrint("Firebase Storage Error: $e");
      return null;
    }
  }

  static String _guessMimeType(String path) {
    final ext = path.split('.').last.toLowerCase();
    switch (ext) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'gif':
        return 'image/gif';
      case 'pdf':
        return 'application/pdf';
      case 'doc':
      case 'docx':
        return 'application/msword';
      default:
        return 'application/octet-stream';
    }
  }
}
