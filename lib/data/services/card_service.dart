import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';
import 'package:aliolo/data/models/card_model.dart';
import 'package:aliolo/data/models/subject_model.dart';
import 'package:aliolo/data/services/auth_service.dart';
import 'package:aliolo/core/utils/logger.dart';

class CardService {
  static final CardService _instance = CardService._internal();
  factory CardService() => _instance;
  CardService._internal();

  SupabaseClient get _supabase => Supabase.instance.client;
  final _authService = AuthService();
  final _uuid = const Uuid();

  static const int minLevel = 1;
  static const int maxLevel = 20;

  bool get hasLocalDb => false;

  Future<void> init() async {}

  Future<List<SubjectModel>> getDashboardSubjects() async {
    final user = _authService.currentUser;
    if (user == null || user.serverId == null) return [];

    final Map<String, SubjectModel> combined = {};

    try {
      // 1. Always get ALL owned subjects
      final List<dynamic> ownedData = await _supabase
          .from('subjects')
          .select('*, cards(id, is_deleted, prompts, answers)')
          .eq('owner_id', user.serverId!);

      for (var json in ownedData) {
        final s = SubjectModel.fromJson(json);
        combined[s.id] = s;
      }

      // 2. Get subjects added from others
      final List<dynamic> dashboardData = await _supabase
          .from('user_subjects')
          .select('subject_id')
          .eq('user_id', user.serverId!);

      final List<String> addedIds =
          dashboardData
              .map((e) => e['subject_id'] as String)
              .where(
                (id) => !combined.containsKey(id),
              ) // Only those we don't already own
              .toList();

      if (addedIds.isNotEmpty) {
        final List<dynamic> addedData = await _supabase
            .from('subjects')
            .select('*, cards(id, is_deleted, prompts, answers)')
            .inFilter('id', addedIds);

        for (var json in addedData) {
          final s = SubjectModel.fromJson(json);
          combined[s.id] = s;
        }
      }

      return combined.values.toList();
    } catch (e) {
      print('Error fetching dashboard subjects: $e');
      return [];
    }
  }

  Future<List<SubjectModel>> getManagementSubjects() async {
    final user = _authService.currentUser;
    if (user == null || user.serverId == null) return [];

    try {
      AppLogger.log('DEBUG: getManagementSubjects for user: ${user.serverId}');
      // 1. Get all public subjects + all owned subjects (filter non-deleted cards)
      final List<dynamic> subjectsData = await _supabase
          .from('subjects')
          .select('*, cards(id, is_deleted)')
          .or('is_public.eq.true,owner_id.eq."${user.serverId!}"');

      AppLogger.log(
        'DEBUG: getManagementSubjects DB raw count: ${subjectsData.length}',
      );
      final allSubjects =
          subjectsData.map((json) => SubjectModel.fromJson(json)).toList();
      AppLogger.log(
        'DEBUG: getManagementSubjects modeled count: ${allSubjects.length}',
      );

      // 2. Get items currently on dashboard (to mark as added)
      final List<dynamic> dashboardData = await _supabase
          .from('user_subjects')
          .select('subject_id')
          .eq('user_id', user.serverId!);

      final Set<String> dashboardIds = {
        for (var item in dashboardData) item['subject_id'] as String,
      };

      // 3. Fetch owner names manually
      final ownerIds = allSubjects.map((s) => s.ownerId).toSet().toList();
      final List<dynamic> profilesData = await _supabase
          .from('profiles')
          .select('id, username')
          .inFilter('id', ownerIds);

      final Map<String, String> namesMap = {
        for (var p in profilesData) p['id'] as String: p['username'] as String,
      };

      final results =
          allSubjects.map((s) {
            return SubjectModel(
              id: s.id,
              name: s.name,
              pillarId: s.pillarId,
              description: s.description,
              ownerId: s.ownerId,
              ownerName: namesMap[s.ownerId],
              isPublic: s.isPublic,
              createdAt: s.createdAt,
              updatedAt: s.updatedAt,
              cardCount: s.cardCount,
              rawCards: s.rawCards,
              isOnDashboard:
                  s.ownerId == user.serverId || dashboardIds.contains(s.id),
            );
          }).toList();

      AppLogger.log(
        'DEBUG: getManagementSubjects final mapped count: ${results.length}',
      );
      return results;
    } catch (e) {
      AppLogger.log('DEBUG: Error in getManagementSubjects: $e');
      return [];
    }
  }

  Future<void> toggleSubjectOnDashboard(String subjectId, bool show) async {
    final user = _authService.currentUser;
    if (user == null || user.serverId == null) return;

    try {
      if (show) {
        await _supabase.from('user_subjects').upsert({
          'user_id': user.serverId,
          'subject_id': subjectId,
        }, onConflict: 'user_id, subject_id');
      } else {
        await _supabase
            .from('user_subjects')
            .delete()
            .eq('user_id', user.serverId!)
            .eq('subject_id', subjectId);
      }
    } catch (e) {
      print('Error in toggleSubjectOnDashboard: $e');
    }
  }

  Future<void> addSubjectToDashboard(String subjectId) async {
    final user = _authService.currentUser;
    if (user == null || user.serverId == null) return;
    try {
      await _supabase.from('user_subjects').upsert({
        'user_id': user.serverId,
        'subject_id': subjectId,
      }, onConflict: 'user_id, subject_id');
    } catch (_) {}
  }

  Future<void> removeSubjectFromDashboard(String subjectId) async {
    final user = _authService.currentUser;
    if (user == null || user.serverId == null) return;
    try {
      await _supabase
          .from('user_subjects')
          .delete()
          .eq('user_id', user.serverId!)
          .eq('subject_id', subjectId);
    } catch (_) {}
  }

  Future<List<SubjectModel>> searchPublicSubjects(String query) async {
    try {
      var request = _supabase.from('subjects').select().eq('is_public', true);
      if (query.isNotEmpty) request = request.ilike('name', '%$query%');
      final List<dynamic> data = await request.limit(50);
      return data.map((json) => SubjectModel.fromJson(json)).toList();
    } catch (_) {
      return [];
    }
  }

  Future<SubjectModel?> getSubjectById(String id) async {
    try {
      final res =
          await _supabase
              .from('subjects')
              .select('*, profiles(username)')
              .eq('id', id)
              .maybeSingle();
      if (res == null) return null;
      return SubjectModel.fromJson(res);
    } catch (e) {
      print('Error fetching subject by id: $e');
      return null;
    }
  }

  Future<List<CardModel>> getCardsBySubject(String subjectId) async {
    try {
      final List<dynamic> data = await _supabase
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

  Future<List<CardModel>> getCardsByPillar(int pillarId) async {
    try {
      final List<dynamic> data = await _supabase
          .from('cards')
          .select('*, subjects!inner(pillar_id)')
          .eq('subjects.pillar_id', pillarId)
          .eq('is_deleted', false);
      return data.map((json) => CardModel.fromJson(json)).toList();
    } catch (e) {
      print('Error fetching cards by pillar: $e');
      return [];
    }
  }

  Future<List<String>> getSubjectsByPillar(int pillarId) async {
    try {
      final List<dynamic> data = await _supabase
          .from('subjects')
          .select('name')
          .eq('pillar_id', pillarId);
      return data.map((e) => e['name'] as String).toSet().toList()..sort();
    } catch (_) {
      return [];
    }
  }

  Future<int?> getPillarForSubject(String subjectName) async {
    try {
      final data =
          await _supabase
              .from('subjects')
              .select('pillar_id')
              .eq('name', subjectName)
              .limit(1)
              .maybeSingle();
      return data?['pillar_id'];
    } catch (_) {
      return null;
    }
  }

  Future<List<({int pillarId, String subject})>> getSubjects() async {
    try {
      final List<dynamic> data = await _supabase
          .from('subjects')
          .select('pillar_id, name');
      return data
          .map(
            (item) => (
              pillarId: item['pillar_id'] as int,
              subject: item['name'] as String,
            ),
          )
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<List<String>> getAvailableLanguages() async {
    return ['EN', 'UK', 'ES', 'FR', 'DE'];
  }

  String generateId() => _uuid.v4();

  Future<void> deleteCard(CardModel card) async {
    await _supabase
        .from('cards')
        .update({'is_deleted': true})
        .eq('id', card.id);
  }

  Future<SubjectModel?> createSubject(
    String name,
    int pillarId, {
    String? description,
    bool isPublic = false,
  }) async {
    final user = _authService.currentUser;
    AppLogger.log(
      'DEBUG: createSubject called. user: ${user?.serverId}, name: $name, pillar: $pillarId',
    );
    if (user == null || user.serverId == null) {
      AppLogger.log('DEBUG: Aborting createSubject - user or serverId is null');
      return null;
    }
    try {
      final payload = {
        'name': name,
        'pillar_id': pillarId,
        'description': description,
        'owner_id': user.serverId,
        'is_public': isPublic,
      };
      AppLogger.log('DEBUG: Sending insert payload: $payload');

      final List<dynamic> res =
          await _supabase.from('subjects').insert(payload).select();
      AppLogger.log('DEBUG: createSubject DB success response: $res');

      if (res.isEmpty) {
        AppLogger.log('DEBUG: Insert succeeded but returned no data.');
        return null;
      }

      final subject = SubjectModel.fromJson(res.first);
      AppLogger.log(
        'DEBUG: SubjectModel created from response ID: ${subject.id}',
      );

      // Automatically add to user_subjects for dashboard visibility
      await addSubjectToDashboard(subject.id);
      AppLogger.log(
        'DEBUG: addSubjectToDashboard called for ID: ${subject.id}',
      );

      return subject;
    } catch (e) {
      AppLogger.log('DEBUG: FATAL Error creating subject: $e');
      if (e is PostgrestException) {
        AppLogger.log(
          'DEBUG: Postgrest Details: ${e.message}, Code: ${e.code}, Hint: ${e.hint}',
        );
      }
      return null;
    }
  }

  Future<void> saveSubject(SubjectModel subject) async {
    try {
      await _supabase.from('subjects').upsert({
        'id': subject.id.isEmpty ? generateId() : subject.id,
        'name': subject.name,
        'pillar_id': subject.pillarId,
        'description': subject.description,
        'owner_id': subject.ownerId,
        'is_public': subject.isPublic,
        'updated_at': DateTime.now().toIso8601String(),
        'created_at': subject.createdAt.toIso8601String(),
      });
    } catch (e) {
      print('Error saving subject: $e');
      rethrow;
    }
  }

  Future<void> deleteSubjectById(String subjectId) async {
    try {
      await _supabase.from('subjects').delete().eq('id', subjectId);
    } catch (e) {
      print('Error deleting subject: $e');
    }
  }

  Future<String?> uploadCardImage(String cardId, File file) async {
    return _uploadImage(cardId, file, file.path);
  }

  Future<String?> uploadCardImageXFile(String cardId, XFile xFile) async {
    return _uploadImage(cardId, xFile, xFile.path);
  }

  Future<String?> _uploadImage(
    String cardId,
    dynamic fileSource,
    String originalPath,
  ) async {
    final user = _authService.currentUser;
    if (user == null || user.serverId == null) return null;

    for (int attempt = 0; attempt < 2; attempt++) {
      try {
        final fileExtension = p.extension(originalPath);
        final fileName =
            'card_${cardId}_${DateTime.now().millisecondsSinceEpoch}$fileExtension';
        final path = '${user.serverId}/$fileName';

        AppLogger.log(
          'DEBUG: Uploading image. Attempt ${attempt + 1}. Path: $path',
        );

        if (attempt == 0)
          await Future.delayed(const Duration(milliseconds: 500));

        if (fileSource is File) {
          await _supabase.storage
              .from('card_images')
              .upload(
                path,
                fileSource,
                fileOptions: const FileOptions(
                  cacheControl: '3600',
                  upsert: true,
                ),
              );
        } else if (fileSource is XFile) {
          final bytes = await fileSource.readAsBytes();
          await _supabase.storage
              .from('card_images')
              .uploadBinary(
                path,
                bytes,
                fileOptions: FileOptions(
                  cacheControl: '3600',
                  upsert: true,
                  contentType: fileSource.mimeType,
                ),
              );
        }

        AppLogger.log('DEBUG: Upload successful.');
        final publicUrl = _supabase.storage
            .from('card_images')
            .getPublicUrl(path);
        return publicUrl;
      } catch (e) {
        AppLogger.log('DEBUG: Attempt ${attempt + 1} failed: $e');
        if (attempt == 0) {
          AppLogger.log('DEBUG: Retrying in 1s...');
          await Future.delayed(const Duration(seconds: 1));
        } else {
          return null;
        }
      }
    }
    return null;
  }

  Future<void> deleteCardImage(String imageUrl) async {
    try {
      // Extract path from public URL
      final uri = Uri.parse(imageUrl);
      final pathSegments = uri.pathSegments;
      // Usually: /storage/v1/object/public/card_images/card_id/file_name
      final bucketIndex = pathSegments.indexOf('card_images');
      if (bucketIndex != -1 && bucketIndex < pathSegments.length - 1) {
        final path = pathSegments.sublist(bucketIndex + 1).join('/');
        await _supabase.storage.from('card_images').remove([path]);
      }
    } catch (e) {
      print('Error deleting card image: $e');
    }
  }

  Future<void> addCard(CardModel card) async {
    try {
      await _supabase.from('cards').upsert({
        'id': card.id.isEmpty ? generateId() : card.id,
        'subject_id': card.subjectId,
        'level': card.level,
        'prompts': card.prompts,
        'answers': card.answers,
        'video_url': card.videoUrl,
        'image_url': card.imageUrl,
        'image_urls': card.imageUrls,
        'owner_id': card.ownerId,
        'is_public': card.isPublic,
        'updated_at': card.updatedAt.toIso8601String(),
        'created_at': card.createdAt.toIso8601String(),
      });
    } catch (e) {
      print('Error adding card: $e');
    }
  }

  Future<void> moveCard(CardModel card, int p, String s) async {}
  Future<void> addCardFile(
    int p,
    String s,
    List<dynamic> i,
    List<String> a, {
    String? videoUrl,
    List<String> prompts = const [],
    String? customFileId,
    int level = 1,
  }) async {}
  Future<CardModel> updateCardFile(
    CardModel o,
    int p,
    String s,
    List<dynamic> ni,
    List<String> na, {
    String? videoUrl,
    List<String> prompts = const [],
    bool ci = false,
    int? level,
  }) async {
    return o;
  }

  Future<void> createSubjectDirectory(int p, String s) async {}
  Future<void> deleteSubject(int p, String s) async {}
  Future<void> syncFileSystem() async {}

  Future<List<CardModel>> getAllCards() async {
    final List<dynamic> data = await _supabase
        .from('cards')
        .select()
        .eq('is_deleted', false);
    return data.map((json) => CardModel.fromJson(json)).toList();
  }
}
