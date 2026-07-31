import 'package:flutter_test/flutter_test.dart';
import 'package:aliolo/data/models/content_item.dart';
import 'package:aliolo/data/models/folder_model.dart';
import 'package:aliolo/data/models/pillar_model.dart';
import 'package:aliolo/data/models/subject_model.dart';
import 'package:aliolo/data/services/discovery_engine.dart';

void main() {
  Pillar pillar(int id) {
    return Pillar(
      id: id,
      icon: 'category',
      lightColor: '#9E9E9E',
      name: 'Pillar $id',
      description: 'Pillar $id',
    );
  }

  SubjectModel subject({
    required String id,
    required int pillarId,
    String? folderId,
    String ownerId = 'user_1',
  }) {
    return SubjectModel.fromJson({
      'id': id,
      'pillar_id': pillarId,
      'owner_id': ownerId,
      'is_public': 1,
      'age_group': 'age_19_25',
      'name': 'Subject $id',
      'description': '',
      'folder_id': folderId,
      'created_at': '2026-04-13T12:00:00Z',
      'updated_at': '2026-04-13T12:00:00Z',
    });
  }

  FolderModel folder({
    required String id,
    required int pillarId,
    String ownerId = 'user_1',
  }) {
    return FolderModel.fromJson({
      'id': id,
      'pillar_id': pillarId,
      'owner_id': ownerId,
      'name': 'Folder $id',
      'created_at': '2026-04-13T12:00:00Z',
      'updated_at': '2026-04-13T12:00:00Z',
    });
  }

  test('filterVisiblePillars hides pillars with no visible content', () {
    final visible = DiscoveryEngine.filterVisiblePillars(
      [pillar(1), pillar(2), pillar(3)],
      [subject(id: 's1', pillarId: 1)],
    );

    expect(visible.map((p) => p.id), [1]);
  });

  test('filterVisiblePillars ignores folder-only pillars', () {
    final visible = DiscoveryEngine.filterVisiblePillars(
      [pillar(1), pillar(2)],
      [
        subject(id: 's1', pillarId: 1),
        folder(id: 'f1', pillarId: 2),
      ],
    );

    expect(visible.map((p) => p.id), [1]);
  });

  test('countPillarContent excludes folders from pillar counts', () {
    final items = <ContentItem>[
      subject(id: 's1', pillarId: 1),
      subject(id: 's2', pillarId: 1),
      folder(id: 'f1', pillarId: 1),
      folder(id: 'f2', pillarId: 2),
    ];

    expect(DiscoveryEngine.countPillarContent(items), {1: 2});
  });

  test('shouldShowFolder hides empty folders in public/favorites views', () {
    final emptyFolder = folder(id: 'f1', pillarId: 1);
    final content = [subject(id: 's1', pillarId: 1, folderId: 'other')];

    expect(
      DiscoveryEngine.shouldShowFolder(
        emptyFolder,
        content,
        collectionFilter: 'favorites',
        myId: 'user_1',
      ),
      isFalse,
    );

    expect(
      DiscoveryEngine.shouldShowFolder(
        emptyFolder,
        content,
        collectionFilter: 'public',
        myId: 'user_1',
      ),
      isFalse,
    );
  });

  test('shouldShowFolder keeps owned empty folders visible in mine view', () {
    final emptyOwnedFolder = folder(id: 'f2', pillarId: 1, ownerId: 'user_1');
    final content = [subject(id: 's1', pillarId: 1, folderId: 'other')];

    expect(
      DiscoveryEngine.shouldShowFolder(
        emptyOwnedFolder,
        content,
        collectionFilter: 'mine',
        myId: 'user_1',
      ),
      isTrue,
    );
  });

  test('shouldShowFolder keeps folders with matching content visible', () {
    final visibleFolder = folder(id: 'f3', pillarId: 1);
    final content = [subject(id: 's1', pillarId: 1, folderId: 'f3')];

    expect(
      DiscoveryEngine.shouldShowFolder(
        visibleFolder,
        content,
        collectionFilter: 'favorites',
        myId: 'user_1',
      ),
      isTrue,
    );
  });
}
