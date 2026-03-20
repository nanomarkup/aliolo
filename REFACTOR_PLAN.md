# Aliolo Architecture Refactor Plan: Folders & Collections

## Current State
- `pillars`: System-level categories (Math, etc.).
- `subjects`: User-level content. Currently some subjects use `type: 'folder'` to act as containers.
- Navigation is Pillar -> Folder-Subject -> Sub-subject.

## Target State
- `pillars`: Static system categories.
- `folders`: User-created containers belonging to a Pillar.
- `subjects`: 
    - `standard`: Contains cards.
    - `collection`: Contains links to other subjects.
- Navigation: Pillar -> (Folders & Subjects/Collections) -> (Subjects/Collections inside Folder).

## Steps

### 1. Database Schema Update
- Create `folders` table.
- Add `folder_id` to `subjects`.
- Add `linked_subject_ids` (JSONB) to `subjects`.
- Add `type` constraint to `subjects` (standard, collection).

### 2. Dart Models
- Create `lib/data/models/folder_model.dart`.
- Update `lib/data/models/subject_model.dart`.

### 3. CardService Update
- Add methods: `getFoldersByPillar`, `addFolder`, `updateFolder`, `deleteFolder`.
- Update `getSubjectsByPillar` to handle root vs folder-nested subjects.

### 4. UI: Navigation Refactor
- Update `PillarSubjectsPage` to show both `FolderModel` and `SubjectModel` items.
- Create `FolderContentPage` (or update `SubSubjectPage`) to handle the new folder structure.

### 5. UI: Editor Refactor
- Update `SubjectEditPage` to handle:
    - Creating a Folder (writes to `folders` table).
    - Creating a Subject (writes to `subjects` table).
    - Creating a Collection (writes to `subjects` table with `type: collection`).
- Add Subject Linker UI for Collections.

## State Log
- [x] Step 1: SQL Execution
- [x] Step 2: Model Updates
- [x] Step 3: Service Layer Updates
- [x] Step 4: UI Navigation
- [x] Step 5: UI Editor
