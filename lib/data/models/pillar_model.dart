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

const List<Pillar> pillars = [
  Pillar(
    id: 1,
    name: 'engineering',
    translations: {"en": "Engineering", "uk": "Інженерія"},
    descriptions: {
      "en": "Mechanics, Architecture, Construction, and Tech",
      "uk": "Механіка, архітектура, будівництво та технології",
    },
    color: '#9E9E9E',
    icon: 'engineering',
  ),
  Pillar(
    id: 2,
    name: 'human_body',
    translations: {"en": "Human Body", "uk": "Тіло людини"},
    descriptions: {
      "en": "Anatomy, Health, Medicine, and Biology",
      "uk": "Анатомія, здоров'я, медицина та біологія",
    },
    color: '#E91E63',
    icon: 'accessibility',
  ),
  Pillar(
    id: 3,
    name: 'humanities',
    translations: {"en": "Humanities", "uk": "Гуманітарні науки"},
    descriptions: {
      "en": "History, Philosophy, Literature, and Arts",
      "uk": "Історія, філософія, література та мистецтво",
    },
    color: '#9C27B0',
    icon: 'menu_book',
  ),
  Pillar(
    id: 4,
    name: 'leisure',
    translations: {"en": "Leisure", "uk": "Дозвілля"},
    descriptions: {
      "en": "Hobbies, Games, Sports, and Music",
      "uk": "Хобі, ігри, спорт та музика",
    },
    color: '#FF9800',
    icon: 'sports_esports',
  ),
  Pillar(
    id: 5,
    name: 'nature',
    translations: {"en": "Nature", "uk": "Природа"},
    descriptions: {
      "en": "Animals, Plants, and Environment",
      "uk": "Тварини, рослини та навколишнє середовище",
    },
    color: '#4CAF50',
    icon: 'eco',
  ),
  Pillar(
    id: 6,
    name: 'academic_prof',
    translations: {"en": "Academic & Prof", "uk": "Академічне та проф."},
    descriptions: {
      "en": "School subjects, Sciences, and Work skills",
      "uk": "Шкільні предмети, науки та професійні навички",
    },
    color: '#2196F3',
    icon: 'school',
  ),
  Pillar(
    id: 7,
    name: 'world',
    translations: {"en": "World", "uk": "Світ"},
    descriptions: {
      "en": "Geography, Cultures, Flags, and Society",
      "uk": "Географія, культури, прапори та суспільство",
    },
    color: '#3F51B5',
    icon: 'public',
  ),
  Pillar(
    id: 8,
    name: 'universal',
    translations: {"en": "Universal", "uk": "Універсальне"},
    descriptions: {
      "en": "Family, Personal, and everything else",
      "uk": "Сім'я, особисте та все інше",
    },
    color: '#795548',
    icon: 'category',
  ),
];
