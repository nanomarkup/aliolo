import 'package:flutter/material.dart';

class Pillar {
  final int id;
  final String name;
  final Map<String, String> translations;
  final Map<String, String> descriptions;
  final String icon;
  final String color;

  const Pillar({
    required this.id,
    required this.name,
    required this.translations,
    required this.descriptions,
    required this.icon,
    required this.color,
  });

  factory Pillar.fromJson(Map<String, dynamic> json) {
    return Pillar(
      id: (json['id'] as num).toInt(),
      name: json['name'] ?? '',
      translations: Map<String, String>.from(json['translations'] ?? {}),
      descriptions: Map<String, String>.from(json['descriptions'] ?? {}),
      icon: json['icon'] ?? 'category',
      color: json['color'] ?? '#9E9E9E',
    );
  }

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
      case 'school':
        return Icons.school;
      case 'public':
        return Icons.public;
      case 'category':
        return Icons.category;
      default:
        return Icons.category;
    }
  }

  String getTranslatedName(String langCode) {
    return translations[langCode.toLowerCase()] ?? translations['en'] ?? name;
  }

  String getTranslatedDescription(String langCode) {
    return descriptions[langCode.toLowerCase()] ?? descriptions['en'] ?? '';
  }
}

// Hard-coded fallback list in case DB is offline during startup
const List<Pillar> fallbackPillars = [
  Pillar(
    id: 1,
    name: 'engineering',
    translations: {"en": "Engineering", "uk": "Інженерія"},
    descriptions: {
      "en": "Mechanics, Architecture,\nConstruction, and Tech",
      "uk": "Механіка, архітектура,\nбудівництво та технології",
    },
    color: '#9E9E9E',
    icon: 'engineering',
  ),
  Pillar(
    id: 2,
    name: 'human_body',
    translations: {"en": "Human Body", "uk": "Тіло людини"},
    descriptions: {
      "en": "Anatomy, Health,\nMedicine, and Biology",
      "uk": "Анатомія, здоров'я,\nмедицина та біологія",
    },
    color: '#E91E63',
    icon: 'accessibility',
  ),
  Pillar(
    id: 3,
    name: 'humanities',
    translations: {"en": "Humanities", "uk": "Гуманітарні науки"},
    descriptions: {
      "en": "History, Philosophy,\nLiterature, and Arts",
      "uk": "Історія, філософія,\nлітература та мистецтво",
    },
    color: '#9C27B0',
    icon: 'menu_book',
  ),
  Pillar(
    id: 4,
    name: 'leisure',
    translations: {"en": "Leisure", "uk": "Дозвілля"},
    descriptions: {
      "en": "Hobbies, Games,\nSports, and Music",
      "uk": "Хобі, ігри,\nспорт та музика",
    },
    color: '#FF9800',
    icon: 'sports_esports',
  ),
  Pillar(
    id: 5,
    name: 'nature',
    translations: {"en": "Nature", "uk": "Природа"},
    descriptions: {
      "en": "Animals, Plants,\nand Environment",
      "uk": "Тварини, рослини\nта довкілля",
    },
    color: '#4CAF50',
    icon: 'eco',
  ),
  Pillar(
    id: 6,
    name: 'academic_prof',
    translations: {"en": "Academic & Prof", "uk": "Академічне та проф."},
    descriptions: {
      "en": "School subjects,\nSciences, and Work skills",
      "uk": "Шкільні предмети,\nнауки та проф. навички",
    },
    color: '#2196F3',
    icon: 'school',
  ),
  Pillar(
    id: 7,
    name: 'world',
    translations: {"en": "World", "uk": "Світ"},
    descriptions: {
      "en": "Geography, Cultures,\nFlags, and Society",
      "uk": "Географія, культури,\nпрапори та суспільство",
    },
    color: '#3F51B5',
    icon: 'public',
  ),
  Pillar(
    id: 8,
    name: 'universal',
    translations: {"en": "Universal", "uk": "Універсальне"},
    descriptions: {
      "en": "Family, Personal,\nand everything else",
      "uk": "Сім'я, особисте\nта все інше",
    },
    color: '#795548',
    icon: 'category',
  ),
];

// Global list that will be populated from DB
List<Pillar> pillars = List.from(fallbackPillars);
