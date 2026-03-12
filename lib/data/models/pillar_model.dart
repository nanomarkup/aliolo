import 'package:flutter/material.dart';

class Pillar {
  final int id;
  final String name;
  final Map<String, String> translations;
  final String icon;
  final String color;

  const Pillar({
    required this.id,
    required this.name,
    required this.translations,
    required this.icon,
    required this.color,
  });

  Color getColor() {
    return Color(int.parse(color.replaceFirst('#', '0xFF')));
  }

  IconData getIconData() {
    switch (icon) {
      case 'engineering':
        return Icons.engineering;
      case 'accessibility':
        return Icons.accessibility;
      case 'menu_book':
        return Icons.menu_book;
      case 'sports_esports':
        return Icons.sports_esports;
      case 'eco':
        return Icons.eco;
      case 'science':
        return Icons.science;
      case 'public':
        return Icons.public;
      case 'translate':
        return Icons.translate;
      default:
        return Icons.category;
    }
  }

  String getTranslatedName(String langCode) {
    return translations[langCode.toLowerCase()] ?? translations['en'] ?? name;
  }
}

const List<Pillar> pillars = [
  Pillar(
    id: 1,
    name: 'engineering',
    translations: {"en": "Engineering", "uk": "Інженерія"},
    color: '#9E9E9E',
    icon: 'engineering',
  ),
  Pillar(
    id: 2,
    name: 'human_body',
    translations: {"en": "Human Body", "uk": "Тіло людини"},
    color: '#E91E63',
    icon: 'accessibility',
  ),
  Pillar(
    id: 3,
    name: 'humanities',
    translations: {"en": "Humanities", "uk": "Гуманітарні науки"},
    color: '#9C27B0',
    icon: 'menu_book',
  ),
  Pillar(
    id: 4,
    name: 'leisure',
    translations: {"en": "Leisure", "uk": "Дозвілля"},
    color: '#FF9800',
    icon: 'sports_esports',
  ),
  Pillar(
    id: 5,
    name: 'nature',
    translations: {"en": "Nature", "uk": "Природа"},
    color: '#4CAF50',
    icon: 'eco',
  ),
  Pillar(
    id: 6,
    name: 'stem',
    translations: {"en": "STEM", "uk": "НТІМ"},
    color: '#2196F3',
    icon: 'science',
  ),
  Pillar(
    id: 7,
    name: 'world',
    translations: {"en": "World", "uk": "Світ"},
    color: '#3F51B5',
    icon: 'public',
  ),
  Pillar(
    id: 8,
    name: 'languages',
    translations: {"en": "Languages", "uk": "Мови"},
    color: '#795548',
    icon: 'translate',
  ),
];
