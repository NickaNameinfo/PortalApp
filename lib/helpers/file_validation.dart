import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:nickname_portal/constants/app_config.dart';

/// File validation utilities for secure file uploads
class FileValidation {
  /// Maximum file size: 500KB
  static const int maxFileSizeBytes = AppConfig.maxFileSizeBytes;

  /// Allowed image MIME types
  static const List<String> allowedImageTypes = AppConfig.allowedImageTypes;

  /// Allowed image file extensions
  static const List<String> allowedImageExtensions = AppConfig.allowedImageExtensions;

  /// Validate file type by extension
  static bool validateFileExtension(String filename) {
    if (filename.isEmpty) return false;
    final extension = filename.toLowerCase().substring(filename.lastIndexOf('.'));
    return allowedImageExtensions.contains(extension);
  }

  /// Validate file size
  static bool validateFileSize(int fileSize) {
    return fileSize <= maxFileSizeBytes;
  }

  /// Get file MIME type from extension
  static String? getMimeTypeFromExtension(String filename) {
    final extension = filename.toLowerCase().substring(filename.lastIndexOf('.'));
    switch (extension) {
      case '.jpg':
      case '.jpeg':
        return 'image/jpeg';
      case '.png':
        return 'image/png';
      case '.webp':
        return 'image/webp';
      default:
        return null;
    }
  }

  /// Comprehensive file validation
  /// Returns error message if invalid, null if valid
  static String? validateFile({
    required String filename,
    required int fileSize,
    String? mimeType,
  }) {
    // Check file size
    if (!validateFileSize(fileSize)) {
      return 'File size exceeds ${maxFileSizeBytes / 1024}KB limit';
    }

    // Check file extension
    if (!validateFileExtension(filename)) {
      return 'File extension not allowed. Allowed: ${allowedImageExtensions.join(", ")}';
    }

    // Check MIME type if provided
    if (mimeType != null && !allowedImageTypes.contains(mimeType.toLowerCase())) {
      return 'File type not allowed. Allowed types: ${allowedImageTypes.join(", ")}';
    }

    return null; // File is valid
  }

  /// Validate XFile (from image_picker)
  static Future<String?> validateXFile(dynamic file) async {
    try {
      String filename;
      int fileSize;
      String? mimeType;

      if (kIsWeb) {
        // Web platform
        final bytes = await file.readAsBytes();
        fileSize = bytes.length;
        filename = file.name;
        mimeType = file.mimeType;
      } else {
        // Mobile platform
        final filePath = file.path;
        final fileObj = File(filePath);
        fileSize = await fileObj.length();
        filename = filePath.split('/').last;
        mimeType = getMimeTypeFromExtension(filename);
      }

      return validateFile(
        filename: filename,
        fileSize: fileSize,
        mimeType: mimeType,
      );
    } catch (e) {
      debugPrint('File validation error: $e');
      return 'Error validating file: $e';
    }
  }
}
