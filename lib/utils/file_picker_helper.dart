import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';

/// Helper class for picking files using the file_picker package
class FilePickerHelper {
  /// Pick a file and return its path
  /// Returns null if the user cancels or an error occurs
  static Future<String?> pickFile({
    List<String> allowedExtensions = const [
      'pem',
      'crt',
      'key',
      'cer',
      'txt',
      'p12',
      'pfx',
    ],
  }) async {
    try {
      final result = await FilePicker.pickFiles(
        type: Platform.isIOS || Platform.isMacOS
            ? FileType.any
            : FileType.custom,
        allowedExtensions: Platform.isIOS || Platform.isMacOS
            ? null
            : allowedExtensions,
      );
      if (result != null && result.files.isNotEmpty) {
        return result.files.first.path;
      }
      return null;
    } catch (e) {
      print('Error picking file: $e');
      return null;
    }
  }

  /// Read file content from path
  static Future<String?> readFileContent(String filePath) async {
    try {
      final file = File(filePath);
      if (await file.exists()) {
        return await file.readAsString();
      }
      return null;
    } catch (e) {
      print('Error reading file: $e');
      return null;
    }
  }

  /// Pick file and read its content in one call
  static Future<FilePickResult?> pickAndReadFile({
    List<String> allowedExtensions = const [
      'pem',
      'crt',
      'key',
      'cer',
      'txt',
      'p12',
      'pfx',
    ],
  }) async {
    try {
      final result = await FilePicker.pickFiles(
        type: Platform.isIOS || Platform.isMacOS
            ? FileType.any
            : FileType.custom,
        allowedExtensions: Platform.isIOS || Platform.isMacOS
            ? null
            : allowedExtensions,
        withData: true,
      );
      if (result == null || result.files.isEmpty) return null;

      final file = result.files.first;
      String? content;

      if (file.bytes != null) {
        try {
          content = utf8.decode(file.bytes!, allowMalformed: true);
        } catch (_) {
          content = String.fromCharCodes(file.bytes!);
        }
      } else if (file.path != null) {
        content = await readFileContent(file.path!);
      }

      if (content == null) return null;

      return FilePickResult(
        path: file.path ?? '',
        content: content,
        fileName: file.name,
      );
    } catch (e) {
      print('Error in pickAndReadFile: $e');
      return null;
    }
  }

  /// Parses a PEM content string and splits it into client certificate,
  /// private key, and CA certificate blocks.
  /// Returns a map with keys: 'clientCert', 'privateKey', 'caCert'.
  static Map<String, String> parseCombinedPem(String content) {
    // Regular expression to match certificate blocks
    final certRegex = RegExp(
      r'-----BEGIN CERTIFICATE-----\r?\n[\s\S]*?\n-----END CERTIFICATE-----',
    );
    // Regular expression to match private key blocks (generic, RSA, EC, encrypted, etc.)
    final keyRegex = RegExp(
      r'-----BEGIN (?:[A-Z0-9 ]+ )?PRIVATE KEY-----\r?\n[\s\S]*?\n-----END (?:[A-Z0-9 ]+ )?PRIVATE KEY-----',
    );

    final certMatches = certRegex
        .allMatches(content)
        .map((m) => m.group(0)!)
        .toList();
    final keyMatches = keyRegex
        .allMatches(content)
        .map((m) => m.group(0)!)
        .toList();

    final result = <String, String>{};

    if (keyMatches.isNotEmpty) {
      result['privateKey'] = keyMatches.first.trim();
    }

    if (certMatches.length == 1) {
      // If only one certificate is found, we assume it's the client certificate.
      result['clientCert'] = certMatches.first.trim();
    } else if (certMatches.length >= 2) {
      // If two or more certificates are found:
      // The first one is typically the client certificate.
      result['clientCert'] = certMatches.first.trim();
      // The rest of the certificates form the CA certificate chain.
      result['caCert'] = certMatches
          .sublist(1)
          .map((c) => c.trim())
          .join('\n\n');
    }

    return result;
  }
}

/// Result class for file pick operations
class FilePickResult {
  final String path;
  final String content;
  final String fileName;

  FilePickResult({
    required this.path,
    required this.content,
    required this.fileName,
  });
}
