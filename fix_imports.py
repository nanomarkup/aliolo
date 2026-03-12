import os
import re

files_to_update = [
    'lib/features/auth/presentation/pages/login_page.dart',
    'lib/features/auth/presentation/pages/profile_page.dart',
    'lib/features/learning/presentation/pages/learning_page.dart',
    'lib/features/management/presentation/pages/add_card_page.dart',
    'lib/features/management/presentation/pages/manage_cards_page.dart',
    'lib/features/management/presentation/pages/manage_learning_langs_page.dart',
    'lib/features/management/presentation/pages/edit_subject_page.dart',
    'lib/features/management/presentation/pages/user_management_page.dart',
    'lib/features/subjects/presentation/pages/subject_page.dart',
    'lib/features/subjects/presentation/pages/sub_subject_page.dart',
    'lib/features/leaderboard/presentation/pages/leaderboard_page.dart',
    'lib/features/settings/presentation/pages/settings_page.dart',
    'lib/features/settings/presentation/pages/about_page.dart',
    'lib/features/settings/presentation/pages/licenses_page.dart',
]

shared_component_map = {
    'window_controls.dart': 'package:aliolo/core/widgets/window_controls.dart',
    'resize_wrapper.dart': 'package:aliolo/core/widgets/resize_wrapper.dart',
}

page_map = {
    'login_page.dart': 'package:aliolo/features/auth/presentation/pages/login_page.dart',
    'profile_page.dart': 'package:aliolo/features/auth/presentation/pages/profile_page.dart',
    'learning_page.dart': 'package:aliolo/features/learning/presentation/pages/learning_page.dart',
    'subject_page.dart': 'package:aliolo/features/subjects/presentation/pages/subject_page.dart',
    'sub_subject_page.dart': 'package:aliolo/features/subjects/presentation/pages/sub_subject_page.dart',
    'manage_cards_page.dart': 'package:aliolo/features/management/presentation/pages/manage_cards_page.dart',
    'add_card_page.dart': 'package:aliolo/features/management/presentation/pages/add_card_page.dart',
    'user_management_page.dart': 'package:aliolo/features/management/presentation/pages/user_management_page.dart',
    'edit_subject_page.dart': 'package:aliolo/features/management/presentation/pages/edit_subject_page.dart',
    'manage_learning_langs_page.dart': 'package:aliolo/features/management/presentation/pages/manage_learning_langs_page.dart',
    'settings_page.dart': 'package:aliolo/features/settings/presentation/pages/settings_page.dart',
    'about_page.dart': 'package:aliolo/features/settings/presentation/pages/about_page.dart',
    'licenses_page.dart': 'package:aliolo/features/settings/presentation/pages/licenses_page.dart',
    'leaderboard_page.dart': 'package:aliolo/features/leaderboard/presentation/pages/leaderboard_page.dart',
}

service_locator_import = "import 'package:aliolo/core/di/service_locator.dart';"

services = [
    'AuthService',
    'CardService',
    'ThemeService',
    'SoundService',
    'ProgressService',
    'TranslationService',
    'SubjectService',
    'LearningLanguageService',
    'MathService',
]

def update_file(file_path):
    if not os.path.exists(file_path):
        print(f"Skipping {file_path}, does not exist.")
        return

    with open(file_path, 'r') as f:
        content = f.read()

    original_content = content

    # 1. Update relative imports
    # Replace shared components
    for old, new in shared_component_map.items():
        content = re.sub(fr"import\s+['\"].*?{old}['\"];", f"import '{new}';", content)
    
    # Replace pages
    for old, new in page_map.items():
        # Avoid replacing the import of the file itself if it's there for some reason
        if os.path.basename(file_path) == old:
            continue
        content = re.sub(fr"import\s+['\"].*?{old}['\"];", f"import '{new}';", content)

    # 2. Update service instantiations
    # final _service = Service(); -> final _service = getIt<Service>();
    for service in services:
        content = re.sub(fr"final\s+(\w+)\s+=\s+{service}\(\);", fr"final \1 = getIt<{service}>();", content)

    # 3. Update direct service calls
    # Service().method() -> getIt<Service>().method()
    # But avoid factory constructors or self-references in services
    if 'data/services' not in file_path:
        for service in services:
            content = re.sub(fr"(?<!class\s)(?<!\w){service}\(\)", f"getIt<{service}>()", content)

    # 4. Ensure service_locator.dart import if getIt is used
    if 'getIt<' in content and service_locator_import not in content:
        # Add after other package imports or at top
        match = re.search(r"import 'package:aliolo/data/services/.*?;", content)
        if match:
            content = content[:match.end()] + "\n" + service_locator_import + content[match.end():]
        else:
            match = re.search(r"import 'package:flutter/.*?;", content)
            if match:
                content = content[:match.end()] + "\n" + service_locator_import + content[match.end():]
            else:
                content = service_locator_import + "\n" + content

    if content != original_content:
        with open(file_path, 'w') as f:
            f.write(content)
        print(f"Updated {file_path}")
    else:
        print(f"No changes needed for {file_path}")

for file_path in files_to_update:
    update_file(file_path)
