import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';
import 'package:path/path.dart' as p;
import 'package:device_info_plus/device_info_plus.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:aliolo/data/models/feedback_model.dart';
import 'package:aliolo/data/models/feedback_reply_model.dart';

class FeedbackService {
  static final FeedbackService _instance = FeedbackService._internal();
  factory FeedbackService() => _instance;
  FeedbackService._internal();

  final _supabase = Supabase.instance.client;
  final _uuid = const Uuid();

  final ValueNotifier<bool> pendingNotifications = ValueNotifier<bool>(false);

  Future<void> submitFeedback(FeedbackModel feedback, List<XFile> attachments) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('User not authenticated');

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
          final fileNameOrig = file.name;
          final fileExt = p.extension(fileNameOrig).toLowerCase();
          final fileName = '${_uuid.v4()}$fileExt';
          final filePath = '$userId/$fileName';

          String contentType = 'image/png';
          if (fileExt == '.jpg' || fileExt == '.jpeg') {
            contentType = 'image/jpeg';
          } else if (fileExt == '.webp') {
            contentType = 'image/webp';
          } else if (fileExt == '.gif') {
            contentType = 'image/gif';
          }

          if (kIsWeb) {
            final bytes = await file.readAsBytes();
            await _supabase.storage.from('feedback_attachments').uploadBinary(
                  filePath,
                  bytes,
                  fileOptions: FileOptions(upsert: true, contentType: contentType),
                );
          } else {
            await _supabase.storage.from('feedback_attachments').upload(
                  filePath,
                  File(file.path),
                  fileOptions: FileOptions(upsert: true, contentType: contentType),
                );
          }

          final url = _supabase.storage
              .from('feedback_attachments')
              .getPublicUrl(filePath);
          uploadedUrls.add(url);
        }
      }

      // 2. Insert feedback record
      final feedbackData = feedback.toJson();
      feedbackData['user_id'] = userId;
      feedbackData['attachment_urls'] = uploadedUrls;
      
      // Merge existing metadata (like context) with our new rich metadata
      final Map<String, dynamic> finalMetadata = Map.from(feedback.metadata);
      finalMetadata.addAll(extraMetadata);
      feedbackData['metadata'] = finalMetadata;

      await _supabase.from('feedbacks').insert(feedbackData);
    } catch (e) {
      debugPrint('Error submitting feedback: $e');
      rethrow;
    }
  }

  Future<List<FeedbackModel>> getFeedbacks() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return [];

      var query = _supabase.from('feedbacks').select('*, profiles(username, email)');
      
      // If not admin, only see own feedback
      if (userId != 'f2fb4c9c-169b-447d-b8a6-dce72c4ed5ac') {
        final response = await query.eq('user_id', userId).order('created_at', ascending: false);
        return (response as List).map((json) => FeedbackModel.fromJson(json)).toList();
      }

      final response = await query.order('created_at', ascending: false);
      return (response as List).map((json) => FeedbackModel.fromJson(json)).toList();
    } catch (e) {
      debugPrint('Error fetching feedbacks: $e');
      return [];
    }
  }

  Future<void> updateFeedbackStatus(String feedbackId, String status) async {
    try {
      await _supabase.from('feedbacks').update({'status': status}).eq('id', feedbackId);
      await hasPendingNotifications(); // Update global badge state
    } catch (e) {
      debugPrint('Error updating feedback status: $e');
      rethrow;
    }
  }

  Future<void> updateFeedbackContent(String feedbackId, String content) async {
    try {
      await _supabase.from('feedbacks').update({'content': content}).eq('id', feedbackId);
    } catch (e) {
      debugPrint('Error updating feedback content: $e');
      rethrow;
    }
  }

  Future<void> updateReplyContent(String replyId, String content) async {
    try {
      await _supabase.from('feedback_replies').update({'content': content}).eq('id', replyId);
    } catch (e) {
      debugPrint('Error updating reply content: $e');
      rethrow;
    }
  }

  Future<void> deleteReply(String replyId) async {
    try {
      // 1. Fetch reply to get attachment URLs
      final res = await _supabase.from('feedback_replies').select('attachment_urls').eq('id', replyId).maybeSingle();
      if (res != null && res['attachment_urls'] != null) {
        final List<String> urls = List<String>.from(res['attachment_urls']);
        final List<String> paths = [];
        for (var url in urls) {
          try {
            final uri = Uri.parse(url);
            final segments = uri.pathSegments;
            if (segments.length >= 8) {
              paths.add(segments.sublist(5).join('/'));
            }
          } catch (_) {}
        }
        if (paths.isNotEmpty) {
          await _supabase.storage.from('feedback_attachments').remove(paths);
        }
      }

      await _supabase.from('feedback_replies').delete().eq('id', replyId);
      await hasPendingNotifications(); // Update global badge state
    } catch (e) {
      debugPrint('Error deleting reply: $e');
      rethrow;
    }
  }

  Future<void> submitReply(FeedbackReplyModel reply, List<XFile> attachments) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('User not authenticated');

      List<String> uploadedUrls = [];
      for (var file in attachments) {
        final fileNameOrig = file.name;
        final fileExt = p.extension(fileNameOrig).toLowerCase();
        final fileName = '${_uuid.v4()}$fileExt';
        final filePath = 'replies/$userId/$fileName';

        String contentType = 'image/png';
        if (fileExt == '.jpg' || fileExt == '.jpeg') {
          contentType = 'image/jpeg';
        } else if (fileExt == '.webp') {
          contentType = 'image/webp';
        }

        if (kIsWeb) {
          final bytes = await file.readAsBytes();
          await _supabase.storage.from('feedback_attachments').uploadBinary(
                filePath,
                bytes,
                fileOptions: FileOptions(upsert: true, contentType: contentType),
              );
        } else {
          await _supabase.storage.from('feedback_attachments').upload(
                filePath,
                File(file.path),
                fileOptions: FileOptions(upsert: true, contentType: contentType),
              );
        }
        uploadedUrls.add(_supabase.storage.from('feedback_attachments').getPublicUrl(filePath));
      }

      final replyData = reply.toJson();
      replyData['user_id'] = userId;
      replyData['attachment_urls'] = uploadedUrls;

      await _supabase.from('feedback_replies').insert(replyData);

      // 3. Automatically update status (which calls hasPendingNotifications internally)
      final isAdmin = userId == 'f2fb4c9c-169b-447d-b8a6-dce72c4ed5ac';
      final newStatus = isAdmin ? 'replied' : 'open';
      await updateFeedbackStatus(reply.feedbackId, newStatus);
    } catch (e) {
      debugPrint('Error submitting reply: $e');
      rethrow;
    }
  }

  Future<List<FeedbackReplyModel>> getReplies(String feedbackId) async {
    try {
      final response = await _supabase
          .from('feedback_replies')
          .select()
          .eq('feedback_id', feedbackId)
          .order('created_at', ascending: true);
      return (response as List).map((json) => FeedbackReplyModel.fromJson(json)).toList();
    } catch (e) {
      debugPrint('Error fetching replies: $e');
      return [];
    }
  }

  Future<bool> hasPendingNotifications() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        pendingNotifications.value = false;
        return false;
      }

      final isAdmin = userId == 'f2fb4c9c-169b-447d-b8a6-dce72c4ed5ac';
      bool hasNotif = false;
      
      if (isAdmin) {
        // Admin: Check for any 'open' feedbacks in the system
        final response = await _supabase
            .from('feedbacks')
            .select('id')
            .eq('status', 'open')
            .limit(1);
        hasNotif = (response as List).isNotEmpty;
      } else {
        // User: Check for own feedbacks with 'replied' status
        final response = await _supabase
            .from('feedbacks')
            .select('id')
            .eq('user_id', userId)
            .eq('status', 'replied')
            .limit(1);
        hasNotif = (response as List).isNotEmpty;
      }
      
      pendingNotifications.value = hasNotif;
      return hasNotif;
    } catch (e) {
      debugPrint('Error checking feedback notifications: $e');
      pendingNotifications.value = false;
      return false;
    }
  }
}
