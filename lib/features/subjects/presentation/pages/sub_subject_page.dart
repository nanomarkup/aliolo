import 'package:flutter/material.dart';
import 'package:aliolo/core/widgets/floating_app_bar.dart';
import 'package:aliolo/data/models/card_model.dart';
import 'package:aliolo/data/models/subject_model.dart';
import 'package:aliolo/data/models/pillar_model.dart';
import 'package:aliolo/data/services/card_service.dart';
import 'package:aliolo/data/services/translation_service.dart';
import 'package:aliolo/core/widgets/resize_wrapper.dart';
import 'package:aliolo/features/testing/presentation/pages/test_page.dart';

class SubSubjectPage extends StatefulWidget {
  final SubjectModel subject;
  const SubSubjectPage({super.key, required this.subject});

  @override
  State<SubSubjectPage> createState() => _SubSubjectPageState();
}

class _SubSubjectPageState extends State<SubSubjectPage> {
  late String _selectedLanguage = 'en';

  @override
  void initState() {
    super.initState();
    _selectedLanguage =
        TranslationService().currentLocale.languageCode.toLowerCase();
  }

  @override
  Widget build(BuildContext context) {
    final pillar = pillars.firstWhere(
      (p) => p.id == widget.subject.pillarId,
      orElse: () => pillars.first,
    );
    final pillarColor = pillar.getColor();
    const appBarColor = Colors.white;

    return ListenableBuilder(
      listenable: TranslationService(),
      builder: (context, _) {
        return ResizeWrapper(
          child: Scaffold(
            extendBodyBehindAppBar: true,
            appBar: AlioloAppBar(
              title: Row(
                children: [
                  Text(
                    widget.subject.getName(_selectedLanguage),
                    style: const TextStyle(color: appBarColor),
                  ),
                  const SizedBox(width: 24),
                  Theme(
                    data: Theme.of(context).copyWith(canvasColor: pillarColor),
                    child: DropdownButton<String>(
                      value: _selectedLanguage,
                      dropdownColor: pillarColor,
                      icon: const Icon(Icons.language, color: appBarColor),
                      style: const TextStyle(color: appBarColor),
                      underline: Container(height: 2, color: appBarColor),
                      onChanged: (String? newValue) {
                        if (newValue != null) {
                          setState(() {
                            _selectedLanguage = newValue;
                          });
                        }
                      },
                      items:
                          TranslationService().availableUILanguages
                              .map<DropdownMenuItem<String>>((String value) {
                                return DropdownMenuItem<String>(
                                  value: value,
                                  child: Text(
                                    TranslationService().getLanguageName(value),
                                  ),
                                );
                              })
                              .toList(),
                    ),
                  ),
                ],
              ),
              backgroundColor: pillarColor,
              actions: [
                IconButton(
                  icon: const Icon(Icons.arrow_back, color: appBarColor),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            body: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 640),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: FutureBuilder<List<CardModel>>(
                    future: CardService().getCardsBySubject(widget.subject.id),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      final cards = snapshot.data ?? [];
                      final filteredCards =
                          cards
                              .where(
                                (c) =>
                                    c.answers.containsKey(_selectedLanguage) ||
                                    c.answers.containsKey('en'),
                              )
                              .toList();

                      return Column(
                        children: [
                          const SizedBox(height: 100),
                          if (widget.subject
                              .getDescription(_selectedLanguage)
                              .isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Text(
                                widget.subject.getDescription(
                                  _selectedLanguage,
                                ),
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey,
                                ),
                              ),
                            ),
                          Expanded(
                            child:
                                filteredCards.isEmpty
                                    ? Center(
                                      child: Text(
                                        context.t('no_cards_found_for_lang'),
                                      ),
                                    )
                                    : ListView.builder(
                                      padding: const EdgeInsets.only(
                                        bottom: 32,
                                      ),
                                      itemCount: filteredCards.length,
                                      itemBuilder: (context, index) {
                                        final card = filteredCards[index];
                                        final answer =
                                            card.answers[_selectedLanguage] ??
                                            card.answers['en'] ??
                                            '';

                                        return Card(
                                          margin: const EdgeInsets.only(
                                            bottom: 12,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                          ),
                                          child: ListTile(
                                            onTap: () {
                                              Navigator.push(
                                                context,
                                                MaterialPageRoute(
                                                  builder:
                                                      (context) => TestPage(
                                                        card: card,
                                                        languageCode:
                                                            _selectedLanguage,
                                                      ),
                                                ),
                                              );
                                            },
                                            leading:
                                                card.imageUrl != null
                                                    ? ClipRRect(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            8,
                                                          ),
                                                      child: Image.network(
                                                        card.imageUrl!,
                                                        width: 50,
                                                        height: 50,
                                                        fit: BoxFit.cover,
                                                      ),
                                                    )
                                                    : const Icon(Icons.image),
                                            title: Text(
                                              answer,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            trailing: const Icon(
                                              Icons.chevron_right,
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
