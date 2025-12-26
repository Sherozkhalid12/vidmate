import 'dart:io';
import 'api_base.dart';

/// Copyright detection API service
class CopyrightApi extends ApiBase {
  // Check video for copyright
  Future<Map<String, dynamic>> checkVideoCopyright({
    required File videoFile,
    String? audioFile,
  }) async {
    final response = await postMultipart(
      '/copyright/check-video',
      videoFile.path,
      'video',
      fields: audioFile != null ? {'audioFile': audioFile} : null,
    );

    return {
      'success': response['success'],
      'hasCopyright': response['hasCopyright'] ?? false,
      'matches': response['matches'] ?? [],
      'confidence': response['confidence'] ?? 0.0,
    };
  }

  // Check audio copyright
  Future<Map<String, dynamic>> checkAudioCopyright(File audioFile) async {
    final response = await postMultipart(
      '/copyright/check-audio',
      audioFile.path,
      'audio',
    );

    return {
      'success': response['success'],
      'hasCopyright': response['hasCopyright'] ?? false,
      'matches': response['matches'] ?? [],
      'confidence': response['confidence'] ?? 0.0,
    };
  }

  // Report copyright violation
  Future<Map<String, dynamic>> reportViolation({
    required String contentId,
    required String reason,
    String? description,
  }) async {
    return await post(
      '/copyright/report',
      {
        'contentId': contentId,
        'reason': reason,
        if (description != null) 'description': description,
      },
    );
  }
}

