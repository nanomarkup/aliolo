import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';
import 'package:path/path.dart' as p;
import 'package:device_info_plus/device_info_plus.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:aliolo/data/models/feedback_model.dart';
import 'package:aliolo/data/models/feedback_reply_model.dart';
import 'package:aliolo/core/network/cloudflare_client.dart';
import 'package:aliolo/core/di/service_locator.dart';
import 'package:dio/dio.dart';
import 'dart:io';

class FeedbackService {
  static final FeedbackService _instance = FeedbackService._internal();
  factory FeedbackService() => _instance;
  FeedbackService._internal();

  final _cfClient = getIt<CloudflareHttpClient>();
  final _uuid = const Uuid();

  final ValueNotifier<bool> pendingNotifications = ValueNotifier<bool>(false);

  Future<void> submitFeedback(FeedbackModel feedback, List<XFile> attachments) async {
    try {
      // 1. Gather Rich Metadata
      final packageInfo = await PackageInfo.fromPlatform();
      final deviceInfo = DeviceInfoPlugin();
      final Map<String, dynamic> extraMetadata = {
        'app_version': packageInfo.version,
        'build_number': packageInfo.buildNumber,
        'platform': kIsWeb ? 'web' : (Platform.isAndroid ? 'android' : (Platform.isIOS ? 'ios' : (Platform.isLinux ? 'linux' : (Platform.isWindows ? 'windows' : 'macos')))),
        'timestamp': DateTime.now().toIso8601String(),
      };

      try {
        if (kIsWeb) {
          final webInfo = await deviceInfo.webBrowserInfo;
          extraMetadata['user_agent'] = webInfo.userAgent;
          extraMetadata['browser'] = webInfo.browserName.name;
          extraMetadata['platform_version'] = webInfo.platform;
        } else if (Platform.isAndroid) {
          final androidInfo = await deviceInfo.androidInfo;
          extraMetadata['os_version'] = androidInfo.version.release;
          extraMetadata['device_model'] = androidInfo.model;
          extraMetadata['brand'] = androidInfo.brand;
        } else if (Platform.isIOS) {
          final iosInfo = await deviceInfo.iosInfo;
          extraMetadata['os_version'] = iosInfo.systemVersion;
          extraMetadata['device_model'] = iosInfo.utsname.machine;
        } else if (Platform.isLinux) {
          final linuxInfo = await deviceInfo.linuxInfo;
          extraMetadata['distro'] = linuxInfo.name;
          extraMetadata['kernel'] = linuxInfo.versionId;
        }
      } catch (e) {
        debugPrint('Error gathering device info: $e');
      }

      List<String> uploadedUrls = [];

      if (attachments.isNotEmpty) {
        for (var file in attachments) {
          final fileExt = p.extension(file.name).toLowerCase();
          final fileName = '${_uuid.v4()}$fileExt';
          final filePath = 'feedback/$fileName';

          final bytes = await file.readAsBytes();
          final response = await _cfClient.client.post(
            '/api/upload/feedback_attachments/$filePath',
            data: Stream.fromIterable([bytes]),
            options: Options(
              headers: {
                Headers.contentTypeHeader: _getContentType(fileExt),
                Headers.contentLengthHeader: bytes.length,
              },
            ),
          );

          if (response.statusCode == 200) {
            uploadedUrls.add(response.data['url']);
          }
        }
      }

      final feedbackData = feedback.toJson();
      feedbackData['attachment_urls'] = uploadedUrls;
      
      final Map<String, dynamic> finalMetadata = Map.from(feedback.metadata);
      finalMetadata.addAll(extraMetadata);
      feedbackData['metadata'] = finalMetadata;

      await _cfClient.client.post('/api/feedbacks', data: feedbackData);
    } catch (e) {
      debugPrint('Error submitting feedback: $e');
      rethrow;
    }
  }

  String _getContentType(String ext) {
    switch (ext) {
      case '.jpg':
      case '.jpeg': return 'image/jpeg';
      case '.webp': return 'image/webp';
      case '.gif': return 'image/gif';
      default: return 'image/png';
    }
  }

  Future<List<FeedbackModel>> getFeedbacks() async {
    try {
      final response = await _cfClient.client.get('/api/feedbacks');
      if (response.statusCode == 200) {
        return (response.data as List).map((json) => FeedbackModel.fromJson(json)).toList();
      }
    } catch (e) {
      debugPrint('Error fetching feedbacks: $e');
    }
    return [];
  }

  Future<void> updateFeedbackStatus(String feedbackId, String status) async {
    try {
      await _cfClient.client.post('/api/feedbacks', data: {
        'id': feedbackId,
        'status': status,
      });
      await hasPendingNotifications();
    } catch (e) {
      debugPrint('Error updating feedback status: $e');
      rethrow;
    }
  }

  Future<void> updateFeedbackContent(String feedbackId, String content) async {
    try {
      await _cfClient.client.post('/api/feedbacks', data: {
        'id': feedbackId,
        'content': content,
      });
    } catch (e) {
      debugPrint('Error updating feedback content: $e');
      rethrow;
    }
  }

  Future<void> updateReplyContent(String replyId, String content) async {
    try {
      await _cfClient.client.post('/api/feedback_replies', data: {
        'id': replyId,
        'content': content,
      });
    } catch (e) {
      debugPrint('Error updating reply content: $e');
      rethrow;
    }
  }

  Future<void> deleteReply(String replyId) async {
    try {
      // Attachment deletion not handled here for brevity, Worker would ideally handle R2 cleanup
      await _cfClient.client.delete('/api/feedback_replies/$replyId');
      await hasPendingNotifications();
    } catch (e) {
      debugPrint('Error deleting reply: $e');
      rethrow;
    }
  }

  Future<void> submitReply(FeedbackReplyModel reply, List<XFile> attachments) async {
    try {
      List<String> uploadedUrls = [];
      for (var file in attachments) {
        final fileExt = p.extension(file.name).toLowerCase();
        final fileName = '${_uuid.v4()}$fileExt';
        final filePath = 'replies/$fileName';

        final bytes = await file.readAsBytes();
        final response = await _cfClient.client.post(
          '/api/upload/feedback_attachments/$filePath',
          data: Stream.fromIterable([bytes]),
          options: Options(
            headers: {
              Headers.contentTypeHeader: _getContentType(fileExt),
              Headers.contentLengthHeader: bytes.length,
            },
          ),
        );
        if (response.statusCode == 200) {
          uploadedUrls.add(response.data['url']);
        }
      }

      final replyData = reply.toJson();
      replyData['attachment_urls'] = uploadedUrls;

      await _cfClient.client.post('/api/feedback_replies', data: replyData);
      await hasPendingNotifications();
    } catch (e) {
      debugPrint('Error submitting reply: $e');
      rethrow;
    }
  }

  Future<List<FeedbackReplyModel>> getReplies(String feedbackId) async {
    try {
      final response = await _cfClient.client.get('/api/feedbacks/$feedbackId/replies');
      if (response.statusCode == 200) {
        return (response.data as List).map((json) => FeedbackReplyModel.fromJson(json)).toList();
      }
    } catch (e) {
      debugPrint('Error fetching replies: $e');
    }
    return [];
  }

  Future<bool> hasPendingNotifications() async {
    try {
      final response = await _cfClient.client.get('/api/feedbacks/notifications');
      if (response.statusCode == 200) {
        final hasNotif = response.data['has_notif'] == true;
        pendingNotifications.value = hasNotif;
        return hasNotif;
      }
    } catch (e) {
      debugPrint('Error checking feedback notifications: $e');
    }
    pendingNotifications.value = false;
    return false;
  }
}
