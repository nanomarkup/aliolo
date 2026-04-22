import json
import os

data_str = """
{
  "en": {
    "level_tier_1": "Level 1",
    "level_tier_2": "Level 2",
    "level_tier_3": "Level 3"
  },
  "id": {
    "level_tier_1": "Tingkat 1",
    "level_tier_2": "Tingkat 2",
    "level_tier_3": "Tingkat 3"
  },
  "bg": {
    "level_tier_1": "Ниво 1",
    "level_tier_2": "Ниво 2",
    "level_tier_3": "Ниво 3"
  },
  "cs": {
    "level_tier_1": "Úroveň 1",
    "level_tier_2": "Úroveň 2",
    "level_tier_3": "Úroveň 3"
  },
  "da": {
    "level_tier_1": "Niveau 1",
    "level_tier_2": "Niveau 2",
    "level_tier_3": "Niveau 3"
  },
  "de": {
    "level_tier_1": "Stufe 1",
    "level_tier_2": "Stufe 2",
    "level_tier_3": "Stufe 3"
  },
  "et": {
    "level_tier_1": "Tase 1",
    "level_tier_2": "Tase 2",
    "level_tier_3": "Tase 3"
  },
  "es": {
    "level_tier_1": "Nivel 1",
    "level_tier_2": "Nivel 2",
    "level_tier_3": "Nivel 3"
  },
  "fr": {
    "level_tier_1": "Niveau 1",
    "level_tier_2": "Niveau 2",
    "level_tier_3": "Niveau 3"
  },
  "ga": {
    "level_tier_1": "Leibhéal 1",
    "level_tier_2": "Leibhéal 2",
    "level_tier_3": "Leibhéal 3"
  },
  "hr": {
    "level_tier_1": "Razina 1",
    "level_tier_2": "Razina 2",
    "level_tier_3": "Razina 3"
  },
  "it": {
    "level_tier_1": "Livello 1",
    "level_tier_2": "Livello 2",
    "level_tier_3": "Livello 3"
  },
  "lv": {
    "level_tier_1": "Līmenis 1",
    "level_tier_2": "Līmenis 2",
    "level_tier_3": "Līmenis 3"
  },
  "lt": {
    "level_tier_1": "1 lygis",
    "level_tier_2": "2 lygis",
    "level_tier_3": "3 lygis"
  },
  "hu": {
    "level_tier_1": "1. szint",
    "level_tier_2": "2. szint",
    "level_tier_3": "3. szint"
  },
  "mt": {
    "level_tier_1": "Livell 1",
    "level_tier_2": "Livell 2",
    "level_tier_3": "Livell 3"
  },
  "nl": {
    "level_tier_1": "Niveau 1",
    "level_tier_2": "Niveau 2",
    "level_tier_3": "Niveau 3"
  },
  "pl": {
    "level_tier_1": "Poziom 1",
    "level_tier_2": "Poziom 2",
    "level_tier_3": "Poziom 3"
  },
  "pt": {
    "level_tier_1": "Nível 1",
    "level_tier_2": "Nível 2",
    "level_tier_3": "Nível 3"
  },
  "ro": {
    "level_tier_1": "Nivelul 1",
    "level_tier_2": "Nivelul 2",
    "level_tier_3": "Nivelul 3"
  },
  "sk": {
    "level_tier_1": "Úroveň 1",
    "level_tier_2": "Úroveň 2",
    "level_tier_3": "Úroveň 3"
  },
  "sl": {
    "level_tier_1": "Raven 1",
    "level_tier_2": "Raven 2",
    "level_tier_3": "Raven 3"
  },
  "fi": {
    "level_tier_1": "Taso 1",
    "level_tier_2": "Taso 2",
    "level_tier_3": "Taso 3"
  },
  "sv": {
    "level_tier_1": "Nivå 1",
    "level_tier_2": "Nivå 2",
    "level_tier_3": "Nivå 3"
  },
  "tl": {
    "level_tier_1": "Antas 1",
    "level_tier_2": "Antas 2",
    "level_tier_3": "Antas 3"
  },
  "vi": {
    "level_tier_1": "Cấp độ 1",
    "level_tier_2": "Cấp độ 2",
    "level_tier_3": "Cấp độ 3"
  },
  "tr": {
    "level_tier_1": "Seviye 1",
    "level_tier_2": "Seviye 2",
    "level_tier_3": "Seviye 3"
  },
  "el": {
    "level_tier_1": "Επίπεδο 1",
    "level_tier_2": "Επίπεδο 2",
    "level_tier_3": "Επίπεδο 3"
  },
  "uk": {
    "level_tier_1": "Рівень 1",
    "level_tier_2": "Рівень 2",
    "level_tier_3": "Рівень 3"
  },
  "ar": {
    "level_tier_1": "المستوى 1",
    "level_tier_2": "المستوى 2",
    "level_tier_3": "المستوى 3"
  },
  "hi": {
    "level_tier_1": "स्तर 1",
    "level_tier_2": "स्तर 2",
    "level_tier_3": "स्तर 3"
  },
  "zh": {
    "level_tier_1": "级别 1",
    "level_tier_2": "级别 2",
    "level_tier_3": "级别 3"
  },
  "ja": {
    "level_tier_1": "レベル 1",
    "level_tier_2": "レベル 2",
    "level_tier_3": "レベル 3"
  },
  "ko": {
    "level_tier_1": "레벨 1",
    "level_tier_2": "레벨 2",
    "level_tier_3": "레벨 3"
  }
}
"""

translations = json.loads(data_str)

sql_commands = []
for lang, keys in translations.items():
    for key, translation in keys.items():
        escaped_translation = translation.replace("'", "''")
        sql_commands.append(f"INSERT OR REPLACE INTO ui_translations (key, lang, value, updated_at) VALUES ('{key}', '{lang}', '{escaped_translation}', CURRENT_TIMESTAMP);")

full_sql = "\n".join(sql_commands)
with open("scripts/sql/update_level_ui.sql", "w") as f:
    f.write(full_sql)

print("SQL script generated at scripts/sql/update_level_ui.sql")
