import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';
import 'package:aliolo/data/models/subject_model.dart';
import 'package:aliolo/data/models/pillar_model.dart';
import 'package:aliolo/data/services/card_service.dart';
import 'package:aliolo/data/services/subject_service.dart';
import 'package:aliolo/data/services/translation_service.dart';
import 'package:aliolo/data/services/learning_language_service.dart';
import 'package:aliolo/data/services/theme_service.dart';
import 'package:aliolo/core/widgets/window_controls.dart';
import 'package:aliolo/core/widgets/resize_wrapper.dart';
import 'package:aliolo/core/di/service_locator.dart';

class EditSubjectPage extends StatefulWidget {
  final String? subjectId;
  final int? pillarId;

  const EditSubjectPage({super.key, this.subjectId, this.pillarId});

  @override
  State<EditSubjectPage> createState() => _EditSubjectPageState();
}

class _EditSubjectPageState extends State<EditSubjectPage> {
  final _cardService = getIt<CardService>();
  final _subjectService = getIt<SubjectService>();
  final _translationService = getIt<TranslationService>();
  final _langService = getIt<LearningLanguageService>();

  final _idController = TextEditingController();
  final Map<String, TextEditingController> _controllers = {};
  
  int? _selectedPillar;
  bool _isLoading = true;
  int _cardCount = 0;

  @override
  void initState() {
    super.initState();
    _selectedPillar = widget.pillarId;
    _idController.text = widget.subjectId ?? '';
    _loadData();
  }

  Future<void> _loadData() async {
    final activeLangs = _langService.activeLanguageCodes;
    Map<String, String> translations = {};
    
    if (widget.subjectId != null) {
      final cards = await _cardService.getCardsBySubject(widget.subjectId!);
      _cardCount = cards.length;
      if (_selectedPillar == null) {
        final subjects = await _cardService.getDashboardSubjects();
        final current = subjects.where((s) => s.id == widget.subjectId).firstOrNull;
        if (current != null) _selectedPillar = current.pillarId;
      }
      
      if (_selectedPillar != null) {
        translations = await _subjectService.getTranslations(_selectedPillar!, widget.subjectId!);
      }
    }

    for (var lang in activeLangs) {
      _controllers[lang] = TextEditingController(text: translations[lang] ?? '');
    }

    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _delete() async {
    // Implementation
  }

  Future<void> _save() async {
    if (_selectedPillar == null) return;
    final id = _idController.text.trim();
    if (id.isEmpty) return;

    final Map<String, String> translations = {};
    _controllers.forEach((lang, ctrl) {
      if (ctrl.text.isNotEmpty) translations[lang] = ctrl.text;
    });

    if (widget.subjectId == null) {
      await _cardService.createSubjectDirectory(_selectedPillar!, id);
    }
    
    await _subjectService.saveTranslations(_selectedPillar!, id, translations);
    if (mounted) {
      Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    const appBarColor = Colors.white;
    const currentSessionColor = ThemeService.mainColor;
    final activeLangs = _langService.activeLanguageCodes.toList()
      ..sort((a, b) => _langService.getLanguageName(a).compareTo(_langService.getLanguageName(b)));
    final isNew = widget.subjectId == null;

    return ListenableBuilder(
      listenable: _translationService,
      builder: (context, _) {
        final String pillarName = _selectedPillar != null 
          ? (pillars.firstWhere((p) => p.id == _selectedPillar).translations[TranslationService().currentLocale.languageCode] ?? pillars.firstWhere((p) => p.id == _selectedPillar).name) 
          : '';
        final String titleText = isNew 
          ? pillarName 
          : '$pillarName > ${widget.subjectId}';

        return ResizeWrapper(
          child: Scaffold(
            appBar: AppBar(
              title: DragToMoveArea(
                child: SizedBox(
                  width: double.infinity,
                  child: Text(titleText, style: const TextStyle(color: appBarColor)),
                ),
              ),
              backgroundColor: currentSessionColor,
              foregroundColor: appBarColor,
              automaticallyImplyLeading: false,
              actions: [
                IconButton(
                  icon: const Icon(Icons.arrow_back, color: appBarColor),
                  onPressed: () => Navigator.pop(context),
                ),
                if (!isNew)
                  IconButton(
                    icon: const Icon(Icons.delete, color: appBarColor),
                    onPressed: _delete,
                  ),
                const WindowControls(color: appBarColor, iconSize: 24),
              ],
            ),
            body: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : Center(
                    child: Container(
                      constraints: const BoxConstraints(maxWidth: 700),
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        children: [
                          TextField(
                            controller: _idController,
                            decoration: const InputDecoration(labelText: 'Subject ID (Internal Name)', border: OutlineInputBorder()),
                            enabled: isNew,
                          ),
                          const SizedBox(height: 24),
                          Expanded(
                            child: ListView.builder(
                              itemCount: activeLangs.length,
                              itemBuilder: (context, index) {
                                final lang = activeLangs[index];
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 16),
                                  child: TextField(
                                    controller: _controllers[lang],
                                    decoration: InputDecoration(
                                      labelText: 'Name in ${_langService.getLanguageName(lang)}',
                                      border: const OutlineInputBorder(),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                          const SizedBox(height: 24),
                          ElevatedButton(
                            onPressed: _save,
                            style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 50), backgroundColor: currentSessionColor, foregroundColor: Colors.white),
                            child: const Text('Save Subject'),
                          ),
                        ],
                      ),
                    ),
                  ),
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _idController.dispose();
    _controllers.forEach((_, c) => c.dispose());
    super.dispose();
  }
}
