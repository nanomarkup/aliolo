import 'dart:convert';
import 'package:aliolo/data/services/translation_service.dart';
import 'package:flutter/material.dart';

class LocalizedPillarData {
  final String? name;
  final String? description;

  LocalizedPillarData({this.name, this.description});

  factory LocalizedPillarData.fromJson(Map<String, dynamic> json) {
    return LocalizedPillarData(
      name: json['name'],
      description: json['description'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (name != null) 'name': name,
      if (description != null) 'description': description,
    };
  }
}

class Pillar {
  final int id;
  final String icon;
  final String lightColor;
  final String? darkColor;
  final int sortOrder;
  final int subjectCount;
  final int folderCount;

  /// Map of language code to its specific data.
  /// Key 'global' is used for primary fallback.
  final Map<String, LocalizedPillarData> localizedData;

  const Pillar({
    required this.id,
    required this.icon,
    required this.lightColor,
    this.darkColor,
    this.sortOrder = 0,
    this.subjectCount = 0,
    this.folderCount = 0,
    this.localizedData = const {},
  });

  factory Pillar.fromJson(Map<String, dynamic> json) {
    final dynamic rawLoc = json['localized_data'];
    Map<String, dynamic> locMap = {};
    
    if (rawLoc is Map) {
      locMap = Map<String, dynamic>.from(rawLoc);
    } else if (rawLoc is String && rawLoc.isNotEmpty) {
      try {
        final decoded = jsonDecode(rawLoc);
        if (decoded is Map) {
          locMap = Map<String, dynamic>.from(decoded);
        }
      } catch (e) {
        print('Error decoding localized_data string for pillar ${json['id']}: $e');
      }
    }

    Map<String, LocalizedPillarData> localized = {};
    if (locMap.isNotEmpty) {
      locMap.forEach((key, value) {
        if (value is Map) {
          localized[key.toString().toLowerCase()] = LocalizedPillarData.fromJson(Map<String, dynamic>.from(value));
        }
      });
    }

    return Pillar(
      id: (json['id'] as num).toInt(),
      icon: json['icon'] ?? 'category',
      lightColor: json['light_color'] ?? json['color'] ?? '#9E9E9E',
      darkColor: json['dark_color'],
      sortOrder: (json['sort_order'] as num? ?? 0).toInt(),
      subjectCount: (json['subject_count'] as num? ?? 0).toInt(),
      folderCount: (json['folder_count'] as num? ?? 0).toInt(),
      localizedData: localized,
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

  /// Helper to get an attribute with smart inheritance
  T? _getInherited<T>(String lang, T? Function(LocalizedPillarData) getter) {
    final lc = lang.toLowerCase();
    // 1. Try requested language
    if (localizedData.containsKey(lc)) {
      final val = getter(localizedData[lc]!);
      if (val != null && val.toString().isNotEmpty) return val;
    }
    // 2. Try 'global'
    if (localizedData.containsKey('global')) {
      final val = getter(localizedData['global']!);
      if (val != null && val.toString().isNotEmpty) return val;
    }
    // 3. Try 'en'
    if (localizedData.containsKey('en')) {
      final val = getter(localizedData['en']!);
      if (val != null && val.toString().isNotEmpty) return val;
    }
    return null;
  }

  String getTranslatedName(String langCode) {
    return _getInherited(langCode, (d) => d.name) ?? 'Pillar $id';
  }

  String getTranslatedDescription(String langCode) {
    return _getInherited(langCode, (d) => d.description) ?? '';
  }
}

// Data is now purely dynamic. Initialized as empty.
List<Pillar> pillars = [];
