import 'package:path/path.dart' as p;
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';
import 'package:aliolo/data/models/card_model.dart';
import 'package:aliolo/data/models/subject_model.dart';
import 'package:aliolo/data/models/pillar_model.dart';
import 'package:aliolo/data/services/auth_service.dart';
import 'package:aliolo/core/utils/logger.dart';

class CardService with ChangeNotifier {
  static final CardService _instance = CardService._internal();
  factory CardService() => _instance;
  CardService._internal();

  SupabaseClient? get _supabase {
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  final _authService = AuthService();
  final _uuid = const Uuid();

  static const int minLevel = 1;
  static const int maxLevel = 20;

  Future<void> init() async {
    if (_supabase != null) {
      await getPillars();
    }
  }

  Future<List<Pillar>> getPillars() async {
    if (_supabase == null) return pillars;
    try {
      final List<dynamic> data = await _supabase!
          .from('pillars')
          .select()
          .order('sort_order', ascending: true);

      final dbPillars = data.map((json) => Pillar.fromJson(json)).toList();
      if (dbPillars.isNotEmpty) {
        pillars = dbPillars;
      }
      return pillars;
    } catch (e) {
      print('Error fetching pillars: $e');
      return pillars;
    }
  }

  Future<List<SubjectModel>> getDashboardSubjects() async {
    final user = _authService.currentUser;
    if (user == null || user.serverId == null) return [];
    final Map<String, SubjectModel> combined = {};
    try {
      final List<dynamic> subjectsData = await _supabase!
          .from('subjects')
          .select(
            '*, profiles(username), cards(id, is_deleted, localized_data)',
          )
          .or('owner_id.eq.${user.serverId!},is_public.eq.true');

      for (var json in subjectsData) {
        final s = SubjectModel.fromJson(json);
        combined[s.id] = s;
      }

      final List<dynamic> dashboardData = await _supabase!
          .from('user_subjects')
          .select('subject_id')
          .eq('user_id', user.serverId!);

      final Set<String> dashboardIds = {
        for (var item in dashboardData) item['subject_id'] as String,
      };

      for (var s in combined.values) {
        s.isOnDashboard =
            s.ownerId == user.serverId || dashboardIds.contains(s.id);
      }
      return combined.values.toList();
    } catch (e) {
      print('Error fetching dashboard subjects: $e');
      return [];
    }
  }

  Future<List<CardModel>> getCardsBySubject(String subjectId) async {
    try {
      final List<dynamic> data = await _supabase!
          .from('cards')
          .select()
          .eq('subject_id', subjectId)
          .eq('is_deleted', false);
      return data.map((json) => CardModel.fromJson(json)).toList();
    } catch (e) {
      print('Error fetching cards: $e');
      return [];
    }
  }

  String generateId() => _uuid.v4();

  Future<void> deleteCard(CardModel card) async {
    await _supabase!
        .from('cards')
        .update({'is_deleted': true})
        .eq('id', card.id);
    notifyListeners();
  }

  Future<void> addCard(CardModel card) async {
    try {
      await _supabase!.from('cards').upsert(card.toJson());
      notifyListeners();
    } catch (e) {
      print('Error adding card: $e');
    }
  }

  // --- Localized Media Uploads ---

  Future<String?> uploadCardImage(
    String cardId,
    XFile file,
    String lang,
  ) async {
    return _uploadFile(
      bucket: 'card_images',
      cardId: cardId,
      file: file,
      lang: lang,
    );
  }

  Future<String?> uploadCardAudio(
    String cardId,
    XFile file,
    String lang,
  ) async {
    return _uploadFile(
      bucket: 'card_audio',
      cardId: cardId,
      file: file,
      lang: lang,
    );
  }

  Future<String?> uploadCardVideo(
    String cardId,
    XFile file,
    String lang,
  ) async {
    return _uploadFile(
      bucket: 'card_videos',
      cardId: cardId,
      file: file,
      lang: lang,
    );
  }

  Future<String?> _uploadFile({
    required String bucket,
    required String cardId,
    required XFile file,
    required String lang,
  }) async {
    final user = _authService.currentUser;
    if (user == null || user.serverId == null) return null;

    final fileExtension = p.extension(file.path);
    final fileName = '${DateTime.now().millisecondsSinceEpoch}$fileExtension';
    // Path: userId / cardId / lang / filename
    final storagePath = '${user.serverId}/$cardId/$lang/$fileName';

    for (int attempt = 0; attempt < 2; attempt++) {
      try {
        final bytes = await file.readAsBytes();
        AppLogger.log(
          'Uploading ${file.name} to $bucket, path: $storagePath, bytes: ${bytes.length}',
        );

        await _supabase!.storage
            .from(bucket)
            .uploadBinary(
              storagePath,
              bytes,
              fileOptions: FileOptions(
                cacheControl: '3600',
                upsert: true,
                contentType: file.mimeType,
              ),
            );

        final url = _supabase!.storage.from(bucket).getPublicUrl(storagePath);
        AppLogger.log('Upload successful. URL: $url');
        return url;
      } catch (e) {
        AppLogger.log('Upload attempt ${attempt + 1} failed: $e');
        if (attempt == 0) await Future.delayed(const Duration(seconds: 1));
      }
    }
    return null;
  }

  Future<void> toggleSubjectOnDashboard(String subjectId, bool show) async {
    final user = _authService.currentUser;
    if (user == null || user.serverId == null) return;

    try {
      if (show) {
        await _supabase!.from('user_subjects').upsert({
          'user_id': user.serverId,
          'subject_id': subjectId,
        }, onConflict: 'user_id, subject_id');
      } else {
        await _supabase!
            .from('user_subjects')
            .delete()
            .eq('user_id', user.serverId!)
            .eq('subject_id', subjectId);
      }
      notifyListeners();
    } catch (e) {
      print('Error in toggleSubjectOnDashboard: $e');
    }
  }

  Future<List<SubjectModel>> getSubjectsByPillar(int pillarId) async {
    final user = _authService.currentUser;
    if (user == null || user.serverId == null) return [];

    try {
      final List<dynamic> data = await _supabase!
          .from('subjects')
          .select(
            '*, profiles(username), cards(id, is_deleted, localized_data)',
          )
          .eq('pillar_id', pillarId)
          .or('is_public.eq.true,owner_id.eq.${user.serverId!}');

      final List<dynamic> dashboardData = await _supabase!
          .from('user_subjects')
          .select('subject_id')
          .eq('user_id', user.serverId!);

      final Set<String> dashboardIds = {
        for (var item in dashboardData) item['subject_id'] as String,
      };

      return data.map((json) {
        final s = SubjectModel.fromJson(json);
        s.isOnDashboard =
            dashboardIds.contains(s.id) || s.ownerId == user.serverId;
        return s;
      }).toList();
    } catch (e) {
      print('Error fetching subjects by pillar: $e');
      return [];
    }
  }

  Future<void> deleteMedia(String url) async {
    try {
      final uri = Uri.parse(url);
      final pathSegments = uri.pathSegments;
      // Find bucket name in segments to extract storage path
      final buckets = ['card_images', 'card_audio', 'card_videos'];
      String? foundBucket;
      int bucketIndex = -1;

      for (var b in buckets) {
        bucketIndex = pathSegments.indexOf(b);
        if (bucketIndex != -1) {
          foundBucket = b;
          break;
        }
      }

      if (foundBucket != null && bucketIndex < pathSegments.length - 1) {
        final path = pathSegments.sublist(bucketIndex + 1).join('/');
        await _supabase!.storage.from(foundBucket).remove([path]);
      }
    } catch (e) {
      print('Error deleting media: $e');
    }
  }

  // --- Subjects ---

  Future<void> saveSubject(SubjectModel subject) async {
    try {
      await _supabase!.from('subjects').upsert({
        'id': subject.id.isEmpty ? generateId() : subject.id,
        'localized_data': subject.localizedData.map(
          (k, v) => MapEntry(k, v.toJson()),
        ),
        'pillar_id': subject.pillarId,
        'owner_id': subject.ownerId,
        'is_public': subject.isPublic,
        'age_group': subject.ageGroup,
        'updated_at': DateTime.now().toIso8601String(),
        'created_at': subject.createdAt.toIso8601String(),
      });
      notifyListeners();
    } catch (e) {
      print('Error saving subject: $e');
      rethrow;
    }
  }

  Future<SubjectModel?> createSubject(
    Map<String, LocalizedSubjectData> localizedData,
    int pillarId, {
    bool isPublic = false,
  }) async {
    final user = _authService.currentUser;
    if (user == null || user.serverId == null) return null;
    try {
      final payload = {
        'localized_data': localizedData.map((k, v) => MapEntry(k, v.toJson())),
        'pillar_id': pillarId,
        'owner_id': user.serverId,
        'is_public': isPublic,
      };
      final List<dynamic> res =
          await _supabase!.from('subjects').insert(payload).select();
      if (res.isEmpty) return null;
      final subject = SubjectModel.fromJson(res.first);
      await _supabase!.from('user_subjects').upsert({
        'user_id': user.serverId,
        'subject_id': subject.id,
      });
      return subject;
    } catch (e) {
      print('Error creating subject: $e');
      return null;
    }
  }

  Future<void> deleteSubjectById(String subjectId) async {
    try {
      await _supabase!.from('subjects').delete().eq('id', subjectId);
      notifyListeners();
    } catch (e) {
      print('Error deleting subject: $e');
    }
  }

  Future<SubjectModel?> getSubjectById(String id) async {
    final user = _authService.currentUser;
    try {
      final res =
          await _supabase!
              .from('subjects')
              .select('*, profiles(username)')
              .eq('id', id)
              .maybeSingle();
      if (res == null) return null;
      final subject = SubjectModel.fromJson(res);
      if (user?.serverId != null) {
        final dashboardCheck =
            await _supabase!
                .from('user_subjects')
                .select()
                .eq('user_id', user!.serverId!)
                .eq('subject_id', id)
                .maybeSingle();
        subject.isOnDashboard =
            subject.ownerId == user.serverId || dashboardCheck != null;
      }
      return subject;
    } catch (e) {
      print('Error fetching subject by id: $e');
      return null;
    }
  }
}
