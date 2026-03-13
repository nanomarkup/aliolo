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

// Data is now purely dynamic. Initialized as empty.
List<Pillar> pillars = [];
