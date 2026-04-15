import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';
import 'package:aliolo/data/models/card_model.dart';
import 'package:aliolo/data/models/subject_model.dart';
import 'package:aliolo/data/models/pillar_model.dart';
import 'package:aliolo/data/models/folder_model.dart';
import 'package:aliolo/data/models/collection_model.dart';
import 'package:aliolo/data/services/auth_service.dart';
import 'package:aliolo/data/services/theme_service.dart';
import 'package:aliolo/core/utils/logger.dart';
import 'package:dio/dio.dart';

import 'package:aliolo/core/network/cloudflare_client.dart';
import 'package:aliolo/core/di/service_locator.dart';

class CardService with ChangeNotifier {
  static final CardService _instance = CardService._internal();
  factory CardService() => _instance;
  CardService._internal();

  final _cfClient = getIt<CloudflareHttpClient>();
  final _authService = AuthService();
  final _uuid = const Uuid();

  static const int minLevel = 1;
  static const int maxLevel = 20;

  List<Pillar> pillars_list = []; // Renamed to avoid shadowing global pillars

  Future<void> init() async {
    await getPillars();
  }

  Future<List<Pillar>> getPillars({String? filter}) async {
    try {
      final response = await _cfClient.client.get(
        '/api/pillars',
        queryParameters: filter != null ? {'filter': filter} : null,
      );
      if (response.statusCode == 200 && response.data != null) {
        final List<dynamic> data = response.data;
        final dbPillars = data.map((json) => Pillar.fromJson(json)).toList();
        if (dbPillars.isNotEmpty) {
          // Update both lists
          pillars.clear();
          pillars.addAll(dbPillars);
          pillars_list = dbPillars;
          ThemeService().forceRefresh();
          notifyListeners();
          return pillars;
        }
      }
    } catch (e) {
      AppLogger.log('Error fetching pillars from Cloudflare: $e');
    }
    return pillars;
  }

  Future<List<SubjectModel>> getDashboardSubjects() async {
    final user = _authService.currentUser;
    if (user == null || user.serverId == null) return [];

    try {
      final response = await _cfClient.client.get('/api/dashboard/subjects');
      if (response.statusCode == 200 && response.data != null) {
        final List<dynamic> data = response.data;
        return data.map((json) {
          final s = SubjectModel.fromJson(json);
          if (json['owner_name'] != null) s.ownerName = json['owner_name'];
          if (json['card_count'] != null) s.cardCount = json['card_count'];
          if (json['is_on_dashboard'] != null)
            s.isOnDashboard = json['is_on_dashboard'] == true;
          return s;
        }).toList();
      }
    } catch (e) {
      AppLogger.log('Error fetching dashboard subjects from Cloudflare: $e');
    }
    return [];
  }

  Future<List<CardModel>> getCardsBySubject(String subjectId) async {
    try {
      final response = await _cfClient.client.get(
        '/api/cards',
        queryParameters: {'subject_id': subjectId},
      );
      if (response.statusCode == 200 && response.data != null) {
        final List<dynamic> data = response.data;
        return data.map((json) => CardModel.fromJson(json)).toList();
      }
    } catch (e) {
      AppLogger.log('Error fetching cards from Cloudflare: $e');
    }
    return [];
  }

  String generateId() => _uuid.v4();

  // --- Media Deletion Helpers ---

  String? _extractFilePathFromUrl(String url) {
    try {
      final uri = Uri.parse(url);
      final pathSegments = uri.pathSegments;
      // URLs look like: /storage/v1/object/public/bucket_id/relative/path/to/file.ext
      if (pathSegments.length >= 5) {
        return pathSegments.sublist(5).join('/');
      }
    } catch (_) {}
    return null;
  }

  Future<void> deleteMediaForCard(CardModel card) async {
    final Map<String, List<String>> bucketFiles = {'aliolo-media': []};

    void addUrl(String? url) {
      if (url == null || url.isEmpty) return;
      final path = _extractFilePathFromUrl(url);
      if (path != null) bucketFiles['aliolo-media']!.add(path);
    }

    // Add base media
    for (var url in card.imagesBase) {
      addUrl(url);
    }
    addUrl(card.audio);
    addUrl(card.video);

    // Add localized media
    for (var urls in card.imagesLocal.values) {
      for (var url in urls) {
        addUrl(url);
      }
    }
    for (var url in card.audios.values) {
      addUrl(url);
    }
    for (var url in card.videos.values) {
      addUrl(url);
    }

    for (var entry in bucketFiles.entries) {
      if (entry.value.isNotEmpty) {
        for (var path in entry.value) {
          try {
            await _cfClient.client.delete('/api/storage/${entry.key}/$path');
          } catch (e) {
            AppLogger.log(
              'Error deleting media from Cloudflare ${entry.key}: $e',
            );
          }
        }
      }
    }
  }

  Future<void> deleteCardMediaFile(String url) async {
    final path = _extractFilePathFromUrl(url);
    if (path == null) return;

    try {
      await _cfClient.client.delete('/api/storage/aliolo-media/$path');
    } catch (e) {
      AppLogger.log(
        'Error deleting media file from Cloudflare aliolo-media: $e',
      );
    }
  }

  Future<void> deleteCard(CardModel card) async {
    try {
      final response = await _cfClient.client.delete('/api/cards/${card.id}');
      if (response.statusCode == 200) {
        notifyListeners();
        return;
      }
    } catch (e) {
      AppLogger.log('Error deleting card via Cloudflare: $e');
    }
  }

  Future<void> addCard(CardModel card) async {
    try {
      final response = await _cfClient.client.post(
        '/api/cards',
        data: card.toJson(),
      );
      if (response.statusCode == 200) {
        notifyListeners();
        return;
      }
    } catch (e) {
      AppLogger.log('Error adding card via Cloudflare: $e');
    }
  }

  // --- Folders ---

  Future<List<FolderModel>> getFoldersByPillar(int pillarId) async {
    try {
      final response = await _cfClient.client.get(
        '/api/folders',
        queryParameters: {'pillar_id': pillarId.toString()},
      );
      if (response.statusCode == 200 && response.data != null) {
        final List<dynamic> data = response.data;
        return data.map((json) {
          final f = FolderModel.fromJson(json);
          if (json['owner_name'] != null) f.ownerName = json['owner_name'];
          return f;
        }).toList();
      }
    } catch (e) {
      AppLogger.log('Error fetching folders from Cloudflare: $e');
    }
    return [];
  }

  Future<List<FolderModel>> getAllFolders() async {
    try {
      final response = await _cfClient.client.get('/api/folders');
      if (response.statusCode == 200 && response.data != null) {
        final List<dynamic> data = response.data;
        return data.map((json) {
          final f = FolderModel.fromJson(json);
          if (json['owner_name'] != null) f.ownerName = json['owner_name'];
          return f;
        }).toList();
      }
    } catch (e) {
      AppLogger.log('Error fetching all folders from Cloudflare: $e');
    }
    return [];
  }

  Future<List<FolderModel>> getFoldersByIds(List<String> ids) async {
    if (ids.isEmpty) return [];
    try {
      final response = await _cfClient.client.get(
        '/api/folders',
        queryParameters: {'ids': ids.join(',')},
      );
      if (response.statusCode == 200 && response.data != null) {
        final List<dynamic> data = response.data;
        return data.map((json) {
          final f = FolderModel.fromJson(json);
          if (json['owner_name'] != null) f.ownerName = json['owner_name'];
          return f;
        }).toList();
      }
    } catch (e) {
      AppLogger.log('Error fetching folders by IDs from Cloudflare: $e');
    }
    return [];
  }

  Future<void> addFolder(FolderModel folder) async {
    try {
      final response = await _cfClient.client.post(
        '/api/folders',
        data: folder.toJson(),
      );
      if (response.statusCode == 200) {
        notifyListeners();
        return;
      }
    } catch (e) {
      AppLogger.log('Error adding folder via Cloudflare: $e');
      rethrow;
    }
  }

  Future<void> updateFolder(FolderModel folder) async {
    try {
      await _cfClient.client.post('/api/folders', data: folder.toJson());
      notifyListeners();
    } catch (e) {
      AppLogger.log('Error updating folder via Cloudflare: $e');
    }
  }

  Future<void> deleteFolder(String folderId) async {
    try {
      final response = await _cfClient.client.delete('/api/folders/$folderId');
      if (response.statusCode == 200) {
        notifyListeners();
        return;
      }
    } catch (e) {
      AppLogger.log('Error deleting folder via Cloudflare: $e');
      rethrow;
    }
  }

  // --- Collections ---

  Future<List<CollectionModel>> getAllCollections({
    bool rootOnly = true,
    String? filter,
  }) async {
    try {
      final queryParams = {
        'root_only': rootOnly.toString(),
        if (filter != null) 'filter': filter,
      };
      final response = await _cfClient.client.get(
        '/api/collections',
        queryParameters: queryParams,
      );
      if (response.statusCode == 200 && response.data != null) {
        final List<dynamic> data = response.data;
        return data.map((json) {
          final c = CollectionModel.fromJson(json);
          if (json['owner_name'] != null) c.ownerName = json['owner_name'];
          if (json['is_on_dashboard'] != null)
            c.isOnDashboard = json['is_on_dashboard'] == true;
          return c;
        }).toList();
      }
    } catch (e) {
      AppLogger.log('Error fetching all collections from Cloudflare: $e');
    }
    return [];
  }

  Future<List<CollectionModel>> getCollectionsByPillar(
    int pillarId, {
    String? folderId,
    bool rootOnly = true,
    String? filter,
  }) async {
    try {
      final queryParams = {
        'pillar_id': pillarId.toString(),
        if (folderId != null) 'folder_id': folderId,
        'root_only': rootOnly.toString(),
        if (filter != null) 'filter': filter,
      };

      final response = await _cfClient.client.get(
        '/api/collections',
        queryParameters: queryParams,
      );

      if (response.statusCode == 200 && response.data != null) {
        final List<dynamic> data = response.data;
        return data.map((json) {
          final c = CollectionModel.fromJson(json);
          if (json['owner_name'] != null) c.ownerName = json['owner_name'];
          if (json['is_on_dashboard'] != null)
            c.isOnDashboard = json['is_on_dashboard'] == true;
          return c;
        }).toList();
      }
    } catch (e) {
      AppLogger.log('Error fetching collections from Cloudflare: $e');
    }
    return [];
  }

  Future<void> addCollection(
    CollectionModel collection,
    List<String> subjectIds,
  ) async {
    try {
      final body = collection.toJson();
      body['subject_ids'] = subjectIds;

      final response = await _cfClient.client.post(
        '/api/collections',
        data: body,
      );
      if (response.statusCode == 200) {
        notifyListeners();
        return;
      }
    } catch (e) {
      AppLogger.log('Error adding collection via Cloudflare: $e');
      rethrow;
    }
  }

  Future<void> toggleCollectionOnDashboard(
    String collectionId,
    bool show,
  ) async {
    try {
      final response = await _cfClient.client.post(
        '/api/dashboard/toggle',
        data: {'collection_id': collectionId, 'show': show},
      );
      if (response.statusCode == 200) {
        notifyListeners();
        return;
      }
    } catch (e) {
      AppLogger.log('Error toggling collection dashboard via Cloudflare: $e');
      rethrow;
    }
  }

  Future<void> deleteCollection(String id) async {
    try {
      final response = await _cfClient.client.delete('/api/collections/$id');
      if (response.statusCode == 200) {
        notifyListeners();
        return;
      }
    } catch (e) {
      AppLogger.log('Error deleting collection via Cloudflare: $e');
    }
  }

  Future<CollectionModel?> getCollectionById(String id) async {
    try {
      final response = await _cfClient.client.get('/api/collections/$id');
      if (response.statusCode == 200) {
        final json = response.data;
        final c = CollectionModel.fromJson(json);
        if (json['owner_name'] != null) c.ownerName = json['owner_name'];
        if (json['is_on_dashboard'] != null)
          c.isOnDashboard = json['is_on_dashboard'] == true;
        return c;
      }
    } catch (e) {
      AppLogger.log('Error fetching collection by id from Cloudflare: $e');
    }
    return null;
  }

  // --- Localized Media Uploads ---

  Future<String?> uploadCardImage(
    String cardId,
    XFile file,
    String lang,
  ) async => _uploadFile(cardId: cardId, file: file, lang: lang);

  Future<String?> uploadCardAudio(
    String cardId,
    XFile file,
    String lang,
  ) async => _uploadFile(cardId: cardId, file: file, lang: lang);

  Future<String?> uploadCardVideo(
    String cardId,
    XFile file,
    String lang,
  ) async => _uploadFile(cardId: cardId, file: file, lang: lang);

  Future<String?> _uploadFile({
    required String cardId,
    required XFile file,
    required String lang,
  }) async {
    final user = _authService.currentUser;
    if (user == null || user.serverId == null) return null;

    try {
      final fileExt = p.extension(file.name).toLowerCase();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      // New flatter structure: cards/{card_id}/{lang}_{timestamp}.{ext}
      final path = 'cards/$cardId/${lang}_$timestamp$fileExt';

      final bytes = await file.readAsBytes();
      final response = await _cfClient.client.post(
        '/api/upload/aliolo-media/$path',
        data: Stream.fromIterable([bytes]),
        options: Options(
          headers: {
            'Content-Type': _getContentType(fileExt),
            'Content-Length': bytes.length,
          },
        ),
      );

      if (response.statusCode == 200) {
        return response.data['url'];
      }
    } catch (e) {
      AppLogger.log('Error uploading file to Cloudflare aliolo-media: $e');
    }
    return null;
  }

  String _getContentType(String ext) {
    switch (ext.toLowerCase()) {
      case '.jpg':
      case '.jpeg':
        return 'image/jpeg';
      case '.png':
        return 'image/png';
      case '.mp3':
        return 'audio/mpeg';
      case '.mp4':
        return 'video/mp4';
      case '.webm':
        return 'video/webm';
      case '.wav':
        return 'audio/wav';
      default:
        return 'application/octet-stream';
    }
  }

  Future<void> addToDashboard(String subjectId) async =>
      toggleSubjectOnDashboard(subjectId, true);
  Future<void> removeFromDashboard(String subjectId) async =>
      toggleSubjectOnDashboard(subjectId, false);

  Future<void> toggleSubjectOnDashboard(String subjectId, bool show) async {
    try {
      final response = await _cfClient.client.post(
        '/api/dashboard/toggle',
        data: {'subject_id': subjectId, 'show': show},
      );
      if (response.statusCode == 200) {
        notifyListeners();
        return;
      }
    } catch (e) {
      AppLogger.log('Error toggling dashboard via Cloudflare: $e');
      rethrow;
    }
  }

  Future<List<SubjectModel>> getSubjectsByPillar(
    int pillarId, {
    String? folderId,
    bool rootOnly = true,
    String? filter,
  }) async {
    try {
      final queryParams = {
        if (pillarId >= 0) 'pillar_id': pillarId.toString(),
        if (folderId != null) 'folder_id': folderId,
        'root_only': rootOnly.toString(),
        if (filter != null) 'filter': filter,
      };

      final response = await _cfClient.client.get(
        '/api/subjects',
        queryParameters: queryParams,
      );

      if (response.statusCode == 200 && response.data != null) {
        final List<dynamic> data = response.data;
        return data.map((json) {
          final s = SubjectModel.fromJson(json);
          if (json['owner_name'] != null) s.ownerName = json['owner_name'];
          if (json['card_count'] != null) s.cardCount = json['card_count'];
          if (json['is_on_dashboard'] != null)
            s.isOnDashboard = json['is_on_dashboard'] == true;
          return s;
        }).toList();
      }
    } catch (e) {
      AppLogger.log('Error fetching subjects from Cloudflare: $e');
    }
    return [];
  }

  Future<void> addSubject(SubjectModel subject) async {
    try {
      final response = await _cfClient.client.post(
        '/api/subjects',
        data: subject.toJson(),
      );
      if (response.statusCode == 200) {
        notifyListeners();
        return;
      }
    } catch (e) {
      AppLogger.log('Error adding subject via Cloudflare: $e');
      rethrow;
    }
  }

  Future<List<SubjectModel>> getSubjectsByIds(List<String> ids) async {
    if (ids.isEmpty) return [];
    try {
      final response = await _cfClient.client.get(
        '/api/subjects',
        queryParameters: {'ids': ids.join(',')},
      );
      if (response.statusCode == 200 && response.data != null) {
        final List<dynamic> data = response.data;
        return data.map((json) {
          final s = SubjectModel.fromJson(json);
          if (json['owner_name'] != null) s.ownerName = json['owner_name'];
          if (json['card_count'] != null) s.cardCount = json['card_count'];
          if (json['is_on_dashboard'] != null)
            s.isOnDashboard = json['is_on_dashboard'] == true;
          return s;
        }).toList();
      }
    } catch (e) {
      AppLogger.log('Error fetching subjects by ids from Cloudflare: $e');
    }
    return [];
  }

  Future<void> deleteSubjectById(String id) async {
    try {
      final response = await _cfClient.client.delete('/api/subjects/$id');
      if (response.statusCode == 200) {
        notifyListeners();
        return;
      }
    } catch (e) {
      AppLogger.log('Error deleting subject via Cloudflare: $e');
      rethrow;
    }
  }

  Future<SubjectModel?> getSubjectById(String id) async {
    try {
      final response = await _cfClient.client.get(
        '/api/subjects',
        queryParameters: {'ids': id},
      );
      if (response.statusCode == 200 && response.data != null) {
        final List<dynamic> data = response.data;
        if (data.isNotEmpty) {
          final s = SubjectModel.fromJson(data.first);
          if (data.first['owner_name'] != null)
            s.ownerName = data.first['owner_name'];
          if (data.first['card_count'] != null)
            s.cardCount = data.first['card_count'];
          if (data.first['is_on_dashboard'] != null)
            s.isOnDashboard = data.first['is_on_dashboard'] == true;
          return s;
        }
      }
    } catch (e) {
      AppLogger.log('Error fetching subject by id from Cloudflare: $e');
    }
    return null;
  }

  Future<List<SubjectCard>> getSubjectCards(
    String subjectId, {
    SubjectModel? subject,
  }) async {
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
