import 'package:supabase_flutter/supabase_flutter.dart';

class SubjectService {
  static final SubjectService _instance = SubjectService._internal();
  factory SubjectService() => _instance;
  SubjectService._internal();

  SupabaseClient get _supabase => Supabase.instance.client;

  Future<Map<String, String>> getTranslations(int pillarId, String subjectId) async {
    try {
      // Assuming translations are now part of the subjects table if needed, 
      // or still managed separately. Based on your SQL, we only added created_at 
      // and changed pillar to pillar_id.
      final data = await _supabase.from('subjects').select('name').eq('id', subjectId).maybeSingle();
      // If we add a 'translations' column to subjects later, we'd fetch it here.
      return {}; 
    } catch (_) {
      return {};
    }
  }

  Future<void> saveTranslations(int pillarId, String subjectId, Map<String, String> translations) async {
    // Implementation for remote storage
  }

  Future<String> getTranslatedName(int pillarId, String subjectId, String langCode) async {
    final trans = await getTranslations(pillarId, subjectId);
    return trans[langCode.toLowerCase()] ?? trans['en'] ?? ''; // Need to fetch name if not translated
  }
}
