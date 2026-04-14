import 'dart:convert';
import 'package:flutter/material.dart';

class Pillar {
  final int id;
  final String icon;
  final String lightColor;
  final String? darkColor;
  final int sortOrder;
  final int subjectCount;
  final int folderCount;
  
  /// Base name (previously from 'global')
  final String name;
  /// Map of language code to its specific name.
  final Map<String, String> names;
  /// Base description (previously from 'global')
  final String description;
  /// Map of language code to its specific description.
  final Map<String, String> descriptions;

  const Pillar({
    required this.id,
    required this.icon,
    required this.lightColor,
    this.darkColor,
    this.sortOrder = 0,
    this.subjectCount = 0,
    this.folderCount = 0,
    required this.name,
    this.names = const {},
    required this.description,
    this.descriptions = const {},
  });

  factory Pillar.fromJson(Map<String, dynamic> json) {
    Map<String, String> namesMap = {};
    final dynamic rawNames = json['names'];
    if (rawNames is Map) {
      namesMap = Map<String, String>.from(rawNames);
    } else if (rawNames is String && rawNames.isNotEmpty) {
      try {
        final decoded = jsonDecode(rawNames);
        if (decoded is Map) {
          namesMap = Map<String, String>.from(decoded);
        }
      } catch (_) {}
    }

    Map<String, String> descriptionsMap = {};
    final dynamic rawDescriptions = json['descriptions'];
    if (rawDescriptions is Map) {
      descriptionsMap = Map<String, String>.from(rawDescriptions);
    } else if (rawDescriptions is String && rawDescriptions.isNotEmpty) {
      try {
        final decoded = jsonDecode(rawDescriptions);
        if (decoded is Map) {
          descriptionsMap = Map<String, String>.from(decoded);
        }
      } catch (_) {}
    }

    return Pillar(
      id: (json['id'] as num).toInt(),
      icon: json['icon'] ?? 'category',
      lightColor: json['light_color'] ?? json['color'] ?? '#9E9E9E',
      darkColor: json['dark_color'],
      sortOrder: (json['sort_order'] as num? ?? 0).toInt(),
      subjectCount: (json['subject_count'] as num? ?? 0).toInt(),
      folderCount: (json['folder_count'] as num? ?? 0).toInt(),
      name: json['name'] ?? '',
      names: namesMap,
      description: json['description'] ?? '',
      descriptions: descriptionsMap,
    );
  }

  Color getColor([bool isDarkMode = false]) {
    final hex = (isDarkMode && darkColor != null) ? darkColor! : lightColor;
    return Color(int.parse(hex.replaceFirst('#', '0xFF')));
  }

  IconData getIconData() {
    switch (icon) {
      case 'engineering':
        return Icons.engineering;
      case 'accessibility':
        return Icons.accessibility;
      case 'human_body':
        return Icons.accessibility;
      case 'menu_book':
        return Icons.menu_book;
      case 'humanities':
        return Icons.menu_book;
      case 'sports_esports':
        return Icons.sports_esports;
      case 'leisure':
        return Icons.sports_esports;
      case 'eco':
        return Icons.eco;
      case 'nature':
        return Icons.eco;
      case 'school':
        return Icons.school;
      case 'stem':
        return Icons.school;
      case 'public':
        return Icons.public;
      case 'world':
        return Icons.public;
      case 'category':
        return Icons.category;
      case 'languages':
        return Icons.translate;
      default:
        return Icons.category;
    }
  }

  String getTranslatedName(String langCode) {
    final lc = langCode.toLowerCase();
    if (names.containsKey(lc) && names[lc]!.isNotEmpty) {
      return names[lc]!;
    }
    // Fallback to base name
    return name.isNotEmpty ? name : 'Pillar $id';
  }

  String getTranslatedDescription(String langCode) {
    final lc = langCode.toLowerCase();
    if (descriptions.containsKey(lc) && descriptions[lc]!.isNotEmpty) {
      return descriptions[lc]!;
    }
    // Fallback to base description
    return description;
  }
}

// Data is now purely dynamic. Initialized as empty.
List<Pillar> pillars = [];
