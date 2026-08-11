# SPEC-06 — Backup & Restoration

- **ID**: SPEC-06
- **Feature**: Supabase Storage JSON Snapshot Backup & Destructive Local Restore
- **Target Lot**: Lot 5 (L5)
- **Status**: 📝 DRAFT
- **Primary Source**: `docs/statoo-cahier-des-charges.md` §6.5, `docs/statoo-design-system.md` §4.6, §5

---

## 1. Context & Goals

Because Statoo stores data locally in SQLite on the user's phone, automatic cloud backups protect against device loss or app re-installation.

The goal of SPEC-06 is to implement:
- Full database snapshot exporter (JSON format).
- Supabase Storage private bucket client upload integration.
- Automated backup trigger after session closure.
- Offline queue & retry on app launch when network returns.
- Backup retention manager (keeps 20 most recent backups).
- Destructive restoration procedure (local DB wipe + full JSON reimport with safety confirmation).

---

## 2. Domain Rules & Invariants

1. **JSON File Schema**:
   - `schema_version` is **MANDATORY** at the very top of the JSON payload.
   - Format:
     ```json
     {
       "schema_version": "1",
       "exported_at": "2026-08-04T21:45:12Z",
       "meta": [...],
       "players": [...],
       "sessions": [...],
       "participations": [...]
     }
     ```
2. **Filename Convention**: `statoo-backup-YYYYMMDD-HHmmss.json`.
3. **Storage Security**: Private Supabase Storage bucket (`statoo-backups`), owner RLS policy.
4. **Offline Resilience**: If offline during session close, snapshot upload fails silently, sets UI status to *"Sauvegarde en attente"*, and retries automatically on next launch when network is available.
5. **Retention**: Max 20 backup files retained in Supabase bucket. Automatically delete the oldest file when uploading a 21st file.
6. **Destructive Restore Safeguards**:
   - Restoration performs a **complete local wipe** before reimporting. No bi-directional sync or merge exists.
   - Rejection if `backup.schema_version` > app current supported `schema_version`.
   - Confirmation requirement: User MUST manually type the group name to enable the destructive button (*"Restaurer et écraser les données"*).

---

## 3. Data Specifications & Interfaces

```ts
export interface BackupMetadata {
  name: string
  created_at: string
  size_bytes: number
  schema_version: string
  session_count: number
}

export interface BackupPayload {
  schema_version: string
  exported_at: string
  meta: Record<string, string>[]
  players: any[]
  sessions: any[]
  participations: any[]
}
```

---

## 4. UI / UX Specifications

### 4.1 Settings Screen Backup Section (`/settings`)
- **Status Row**: Indicator dot + text: *"Sauvegardé il y a 2 jours"* (or *"Sauvegarde en attente"* with `flag-400` indicator dot).
- **Actions**:
  - Ghost button: `"Sauvegarder maintenant"`.
  - Link item: `"Restaurer une sauvegarde"`.

### 4.2 Restoration Selection Screen (`/settings/restore`)
- List of available remote backups in Supabase Storage with radio selector.
- Warning Card: Red alert container (`flag-950` background, `flag-700` border) with warning header *"Cette action est irréversible"*.
- Text confirmation input: *"Tapez le nom du groupe pour confirmer"*.
- Action buttons: `"Annuler"` above disabled/active red button `"Restaurer et écraser"`.

---

## 5. Technical Implementation Plan

### 5.1 Modules Structure
```
app/
  lib/
    backup/
      exporter.ts          # Generates JSON object from SQLite tables
      importer.ts          # Wipes SQLite tables and inserts JSON records inside a transaction
      supabaseClient.ts    # Supabase Storage client wrapper
  composables/
    useBackup.ts           # State machine for backup status, trigger, and restore
```

### 5.2 Composable API (`useBackup.ts`)
```ts
export function useBackup() {
  const lastBackupDate = ref<string | null>(null)
  const isPending = ref<boolean>(false)
  const availableBackups = ref<BackupMetadata[]>([])
  
  async function createBackupSnapshot(): Promise<boolean>
  async function listBackups(): Promise<BackupMetadata[]>
  async function restoreBackup(backupName: string): Promise<boolean>
}
```

---

## 6. Edge Cases & Error Handling

- **Version Mismatch on Restore**: If backup `schema_version` is `"2"` and app schema version is `"1"`, reject restore with alert: *"Cette sauvegarde provient d'une version plus récente de l'application."*
- **Partial Restore Failure**: Transaction ensures that if any JSON row fails to insert during restore, the transaction rolls back completely.

---

## 7. Verification & Testing Plan

### Automated Tests
- Test JSON export includes all 3 tables + `meta`.
- Test restore transaction wipes local DB and restores exact state.
- Test rejection of backup payload with unsupported `schema_version`.

### Manual Verification
- Close session -> verify backup file created in Supabase Storage -> perform restore on another device/clean state -> verify all sessions and stats match.
