import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';
import 'package:aliolo/data/models/card_model.dart';
import 'package:aliolo/data/models/subject_model.dart';
import 'package:aliolo/data/models/pillar_model.dart';
import 'package:aliolo/data/models/folder_model.dart';
import 'package:aliolo/data/models/collection_model.dart';
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
          .select('*')
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
          .select('*, profiles!fk_subjects_owner(username), cards(id, is_deleted, localized_data)')
          .or('owner_id.eq.${user.serverId},is_public.eq.true');

      for (var json in subjectsData) {
        final s = SubjectModel.fromJson(json);
        combined[s.id] = s;
      }

      final List<dynamic> dashboardData = await _supabase!
          .from('user_subjects')
          .select('subject_id')
          .eq('user_id', user.serverId!)
          .not('subject_id', 'is', null);

      final Set<String> dashboardIds = {
        for (var item in dashboardData) item['subject_id'].toString(),
      };

      for (var s in combined.values) {
        s.isOnDashboard = dashboardIds.contains(s.id);
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
          .select('*')
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

  // --- Folders ---

  Future<List<FolderModel>> _withFolderAuthors(List<dynamic> data) async {
    if (data.isEmpty) return [];
    
    final Set<String> ownerIds = data.map((e) => e['owner_id'].toString()).toSet();
    final List<dynamic> profilesData = await _supabase!
        .from('profiles')
        .select('id, username')
        .inFilter('id', ownerIds.toList());
    
    final Map<String, String> profileMap = {
      for (var p in profilesData) p['id'].toString(): p['username']?.toString() ?? 'Unknown'
    };

    return data.map((json) {
      final ownerId = json['owner_id'];
      final username = profileMap[ownerId];
      // Inject profile for FolderModel.fromJson
      if (username != null) {
        json['profiles'] = {'username': username};
      }
      return FolderModel.fromJson(json);
    }).toList();
  }

  Future<List<FolderModel>> getFoldersByPillar(int pillarId) async {
    final user = _authService.currentUser;
    if (user == null || user.serverId == null) return [];
    try {
      final List<dynamic> data = await _supabase!
          .from('folders')
          .select('*, subjects(count), collections(count)')
          .eq('pillar_id', pillarId);
      return _withFolderAuthors(data);
    } catch (e) {
      print('Error fetching folders by pillar: $e');
      return [];
    }
  }

  Future<List<FolderModel>> getAllFolders() async {
    final user = _authService.currentUser;
    if (user == null || user.serverId == null) return [];
    try {
      final List<dynamic> data = await _supabase!
          .from('folders')
          .select('*, subjects(count), collections(count)');
      return _withFolderAuthors(data);
    } catch (e) {
      print('Error fetching all folders: $e');
      return [];
    }
  }

  Future<List<FolderModel>> getFoldersByIds(List<String> ids) async {
    if (ids.isEmpty) return [];
    try {
      final List<dynamic> data = await _supabase!
          .from('folders')
          .select('*, subjects(count), collections(count)')
          .inFilter('id', ids);
      return _withFolderAuthors(data);
    } catch (e) {
      print('Error fetching folders by IDs: $e');
      return [];
    }
  }

  Future<void> addFolder(FolderModel folder) async {
    try {
      await _supabase!.from('folders').upsert(folder.toJson());
      notifyListeners();
    } catch (e) {
      print('Error adding folder: $e');
      rethrow;
    }
  }

  Future<void> updateFolder(FolderModel folder) async {
    try {
      await _supabase!
          .from('folders')
          .update(folder.toJson())
          .eq('id', folder.id);
      notifyListeners();
    } catch (e) {
      print('Error updating folder: $e');
    }
  }

  Future<void> deleteFolder(String folderId) async {
    try {
      final subjects = await _supabase!.from('subjects').select('id').eq('folder_id', folderId).limit(1);
      if (subjects.isNotEmpty) throw Exception('folder_not_empty');

      final collections = await _supabase!.from('collections').select('id').eq('folder_id', folderId).limit(1);
      if (collections.isNotEmpty) throw Exception('folder_not_empty');

      await _supabase!.from('folders').delete().eq('id', folderId);
      notifyListeners();
    } catch (e) {
      print('Error deleting folder: $e');
      rethrow;
    }
  }

  // --- Collections ---

  Future<List<CollectionModel>> getAllCollections({bool rootOnly = true}) async {
    final user = _authService.currentUser;
    if (user == null || user.serverId == null) return [];
    try {
      var query = _supabase!
          .from('collections')
          .select('*, profiles(username), collection_items(subject_id)')
          .or('owner_id.eq.${user.serverId},is_public.eq.true');

      
      if (rootOnly) {
        query = query.filter('folder_id', 'is', null);
      }

      final List<dynamic> data = await query;
      final collections = data.map((json) => CollectionModel.fromJson(json)).toList();

      final List<dynamic> dashboardData = await _supabase!
          .from('user_subjects')
          .select('collection_id')
          .eq('user_id', user.serverId!)
          .not('collection_id', 'is', null);

      final Set<String> dashboardIds = {
        for (var item in dashboardData) item['collection_id'].toString(),
      };

      for (var c in collections) {
        c.isOnDashboard = dashboardIds.contains(c.id);
      }

      return collections;
    } catch (e) {
      print('Error fetching all collections: $e');
      return [];
    }
  }

  Future<List<CollectionModel>> getCollectionsByPillar(int pillarId, {String? folderId, bool rootOnly = true}) async {
    final user = _authService.currentUser;
    if (user == null || user.serverId == null) return [];
    try {
      var query = _supabase!
          .from('collections')
          .select('*, profiles(username), collection_items(subject_id)')
          .eq('pillar_id', pillarId)
          .or('owner_id.eq.${user.serverId},is_public.eq.true');

      
      if (folderId != null) {
        query = query.eq('folder_id', folderId);
      } else if (rootOnly) {
        query = query.filter('folder_id', 'is', null);
      }

      final List<dynamic> data = await query;
      final collections = data.map((json) => CollectionModel.fromJson(json)).toList();

      final List<dynamic> dashboardData = await _supabase!
          .from('user_subjects')
          .select('collection_id')
          .eq('user_id', user.serverId!)
          .not('collection_id', 'is', null);

      final Set<String> dashboardIds = {
        for (var item in dashboardData) item['collection_id'].toString(),
      };

      for (var c in collections) {
        c.isOnDashboard = dashboardIds.contains(c.id);
      }

      return collections;
    } catch (e) {
      print('Error fetching collections by pillar: $e');
      return [];
    }
  }

  Future<void> addCollection(CollectionModel collection, List<String> subjectIds) async {
    final user = _authService.currentUser;
    try {
      await _supabase!.from('collections').upsert(collection.toJson());
      
      // Update bridge table: remove old, add new
      await _supabase!.from('collection_items').delete().eq('collection_id', collection.id);
      
      if (subjectIds.isNotEmpty) {
        final List<Map<String, dynamic>> items = subjectIds.map((sid) => {
          'collection_id': collection.id,
          'subject_id': sid,
        }).toList();
        await _supabase!.from('collection_items').insert(items);
      }

      if (user?.serverId != null) {
        if (collection.isOnDashboard) {
          await _supabase!.from('user_subjects').upsert({
            'user_id': user!.serverId!,
            'collection_id': collection.id,
            'subject_id': null,
          }, onConflict: 'user_id, subject_id, collection_id');
        } else {
          await _supabase!
              .from('user_subjects')
              .delete()
              .eq('user_id', user!.serverId!)
              .eq('collection_id', collection.id);
        }
      }
      
      notifyListeners();
    } catch (e) {
      print('Error adding collection: $e');
      rethrow;
    }
  }

  Future<void> toggleCollectionOnDashboard(String collectionId, bool show) async {
    final user = _authService.currentUser;
    if (user == null || user.serverId == null) return;

    try {
      if (show) {
        await _supabase!.from('user_subjects').upsert({
          'user_id': user.serverId,
          'collection_id': collectionId,
          'subject_id': null,
        }, onConflict: 'user_id, subject_id, collection_id');
      } else {
        await _supabase!
            .from('user_subjects')
            .delete()
            .eq('user_id', user.serverId!)
            .eq('collection_id', collectionId);
      }
      notifyListeners();
    } catch (e) {
      print('Error in toggleCollectionOnDashboard: $e');
      rethrow;
    }
  }

  Future<void> deleteCollection(String id) async {
    try {
      await _supabase!.from('collections').delete().eq('id', id);
      notifyListeners();
    } catch (e) {
      print('Error deleting collection: $e');
    }
  }

  Future<CollectionModel?> getCollectionById(String id) async {
    final user = _authService.currentUser;
    try {
      final data = await _supabase!
          .from('collections')
          .select('*, collection_items(subject_id)')
          .eq('id', id)
          .single();
      final collection = CollectionModel.fromJson(data);
      if (user?.serverId != null) {
        final dashboardCheck = await _supabase!
            .from('user_subjects')
            .select('*')
            .eq('user_id', user!.serverId!)
            .eq('collection_id', id)
            .maybeSingle();
        collection.isOnDashboard = dashboardCheck != null;
      }
      return collection;
    } catch (e) {
      print('Error fetching collection by id: $e');
      return null;
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

    try {
      final fileExt = p.extension(file.path);
      final fileName = '${cardId}_${DateTime.now().millisecondsSinceEpoch}$fileExt';
      final path = '${user.serverId}/$lang/$fileName';

      if (kIsWeb) {
        final bytes = await file.readAsBytes();
        await _supabase!.storage.from(bucket).uploadBinary(path, bytes);
      } else {
        await _supabase!.storage.from(bucket).upload(path, File(file.path));
      }

      return _supabase!.storage.from(bucket).getPublicUrl(path);
    } catch (e) {
      print('Error uploading file to $bucket: $e');
      return null;
    }
  }

  Future<void> addToDashboard(String subjectId) async {
    await toggleSubjectOnDashboard(subjectId, true);
  }

  Future<void> removeFromDashboard(String subjectId) async {
    await toggleSubjectOnDashboard(subjectId, false);
  }

  Future<void> toggleSubjectOnDashboard(String subjectId, bool show) async {
    final user = _authService.currentUser;
    if (user == null || user.serverId == null) return;

    try {
      if (show) {
        await _supabase!.from('user_subjects').upsert({
          'user_id': user.serverId,
          'subject_id': subjectId,
          'collection_id': null,
        }, onConflict: 'user_id, subject_id, collection_id');
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
      rethrow;
    }
  }

  Future<List<SubjectModel>> getSubjectsByPillar(int pillarId, {String? folderId, bool rootOnly = true}) async {
    final user = _authService.currentUser;
    if (user == null || user.serverId == null) return [];

    try {
      var query = _supabase!
          .from('subjects')
          .select(
            '*, profiles!fk_subjects_owner(username), cards(id, is_deleted, localized_data)',
          );
      
      if (folderId != null) {
        query = query.eq('folder_id', folderId);
      } else if (rootOnly) {
        query = query.eq('pillar_id', pillarId).filter('folder_id', 'is', null);
      } else {
        query = query.eq('pillar_id', pillarId);
      }

      query = query.or('is_public.eq.true,owner_id.eq.${user.serverId}');


      final List<dynamic> data = await query;

      final List<dynamic> dashboardData = await _supabase!
          .from('user_subjects')
          .select('subject_id')
          .eq('user_id', user.serverId!)
          .not('subject_id', 'is', null);

      final Set<String> dashboardIds = {
        for (var item in dashboardData) item['subject_id'].toString(),
      };

      final subjects = data.map((json) => SubjectModel.fromJson(json)).toList();
      for (var s in subjects) {
        s.isOnDashboard = dashboardIds.contains(s.id);
      }
      return subjects;
    } catch (e) {
      print('Error fetching subjects by pillar: $e');
      return [];
    }
  }

  Future<void> addSubject(SubjectModel subject) async {
    final user = _authService.currentUser;
    try {
      await _supabase!.from('subjects').upsert(subject.toJson());
      
      if (user?.serverId != null) {
        if (subject.isOnDashboard) {
          await _supabase!.from('user_subjects').upsert({
            'user_id': user!.serverId!,
            'subject_id': subject.id,
            'collection_id': null,
          }, onConflict: 'user_id, subject_id, collection_id');
        } else {
          await _supabase!
              .from('user_subjects')
              .delete()
              .eq('user_id', user!.serverId!)
              .eq('subject_id', subject.id);
        }
      }
      
      notifyListeners();
    } catch (e) {
      print('Error adding subject: $e');
      rethrow;
    }
  }

  Future<List<SubjectModel>> getSubjectsByIds(List<String> ids) async {
    final user = _authService.currentUser;
    if (user == null || ids.isEmpty) return [];

    try {
      final List<dynamic> data = await _supabase!
          .from('subjects')
          .select(
            '*, profiles!fk_subjects_owner(username), cards(id, is_deleted, localized_data)',
          )
          .inFilter('id', ids);

      final List<dynamic> dashboardData = await _supabase!
          .from('user_subjects')
          .select('subject_id')
          .eq('user_id', user.serverId!)
          .not('subject_id', 'is', null);

      final Set<String> dashboardIds = {
        for (var item in dashboardData) item['subject_id'].toString(),
      };

      final subjects = data.map((json) => SubjectModel.fromJson(json)).toList();
      for (var s in subjects) {
        s.isOnDashboard = dashboardIds.contains(s.id);
      }
      return subjects;
    } catch (e) {
      print('Error fetching subjects by ids: $e');
      return [];
    }
  }

  Future<void> deleteSubjectById(String id) async {
    try {
      await _supabase!.from('cards').delete().eq('subject_id', id);
      await _supabase!.from('subjects').delete().eq('id', id);
      notifyListeners();
    } catch (e) {
      print('Error deleting subject: $e');
    }
  }

  Future<SubjectModel?> getSubjectById(String id) async {
    final user = _authService.currentUser;
    if (user == null) return null;
    try {
      final data = await _supabase!
          .from('subjects')
          .select('*, profiles(username), cards(id, is_deleted, localized_data)')
          .eq('id', id)
          .single();

      final subject = SubjectModel.fromJson(data);
      final dashboardCheck = await _supabase!
          .from('user_subjects')
          .select('*')
          .eq('user_id', user.serverId!)
          .eq('subject_id', id)
          .maybeSingle();
      subject.isOnDashboard = dashboardCheck != null;
      return subject;
    } catch (e) {
      print('Error fetching subject by id: $e');
      return null;
    }
  }

  Future<List<SubjectCard>> getSubjectCards(String subjectId, {SubjectModel? subject}) async {
    final s = subject ?? await getSubjectById(subjectId);
    if (s == null) return [];
    final cards = await getCardsBySubject(subjectId);
    return cards.map((c) => SubjectCard(card: c, subject: s)).toList();
  }

  Future<List<SubjectCard>> getCollectionCards(List<String> subjectIds) async {
    final List<SubjectCard> all = [];
    if (subjectIds.isEmpty) return all;
    final subjects = await getSubjectsByIds(subjectIds);
    for (final s in subjects) {
      final cards = await getCardsBySubject(s.id);
      all.addAll(cards.map((c) => SubjectCard(card: c, subject: s)));
    }
    return all;
  }
}
