import os
import json

base_path = "/home/vitaliinoha/.aliolo/cards"
subjects_translation = {
    "Animals": {"en": "Animals", "uk": "Тварини"},
    "Architectural Styles": {"en": "Architectural Styles", "uk": "Архітектурні стилі"},
    "Astronomy": {"en": "Astronomy", "uk": "Астрономія"},
    "Botany": {"en": "Botany", "uk": "Ботаніка"},
    "Dog Breeds": {"en": "Dog Breeds", "uk": "Породи собак"},
    "Famous Art": {"en": "Famous Art", "uk": "Відоме мистецтво"},
    "Flags of the World": {"en": "Flags of the World", "uk": "Прапори світу"},
    "Food & Cuisines": {"en": "Food & Cuisines", "uk": "Їжа та кухні"},
    "Historical Figures": {"en": "Historical Figures", "uk": "Історичні постаті"},
    "Human Anatomy": {"en": "Human Anatomy", "uk": "Анатомія людини"},
    "Insects": {"en": "Insects", "uk": "Комахи"},
    "Minerals & Elements": {"en": "Minerals & Elements", "uk": "Мінерали та елементи"},
    "Musical Instruments": {"en": "Musical Instruments", "uk": "Музичні інструменти"},
    "Mythology": {"en": "Mythology", "uk": "Міфологія"},
    "Ocean Life": {"en": "Ocean Life", "uk": "Океанічне життя"},
    "Sports": {"en": "Sports", "uk": "Спорт"},
    "Tech & Gadgets": {"en": "Tech & Gadgets", "uk": "Технології та гаджети"},
    "Vehicles": {"en": "Vehicles", "uk": "Транспортні засоби"},
    "World Bridges": {"en": "World Bridges", "uk": "Мости світу"},
    "World Landmarks": {"en": "World Landmarks", "uk": "Світові пам'ятки"},
}

for subject, translations in subjects_translation.items():
    subject_dir = os.path.join(base_path, subject)
    if os.path.exists(subject_dir):
        meta_path = os.path.join(subject_dir, "meta.json")
        data = {"name": translations}
        with open(meta_path, "w", encoding="utf-8") as f:
            json.dump(data, f, ensure_ascii=False, indent=2)
        print(f"Updated {subject}")
    else:
        print(f"Subject {subject} not found at {subject_dir}")
