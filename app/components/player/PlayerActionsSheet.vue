<template>
  <Teleport to="body">
    <Transition name="sheet">
      <div
        v-if="player"
        class="sheet-overlay"
        @click.self="closeSheet"
      >
        <div class="sheet-panel" role="dialog" aria-modal="true">
          <div class="sheet-handle" />

          <!-- Player header -->
          <div class="sheet-header">
            <div class="sheet-avatar">{{ initials(player.name) }}</div>
            <div>
              <div class="sheet-player-name">{{ player.name }}</div>
              <div v-if="player.nickname" class="sheet-player-nick">{{ player.nickname }}</div>
            </div>
          </div>

          <!-- Content Switcher -->
          <Transition name="fade" mode="out-in">
            <!-- Full menu -->
            <div v-if="mode === 'menu'" key="menu" class="sheet-menu">
              <button class="sheet-action" @click="$emit('edit')">
                <UIcon name="i-heroicons-pencil-square" class="sheet-action-icon" />
                Modifier
              </button>
              <div class="sheet-divider" />
              <button class="sheet-action" @click="mode = 'confirm-archive'">
                <UIcon
                  :name="player.is_active ? 'i-heroicons-archive-box' : 'i-heroicons-archive-box-x-mark'"
                  class="sheet-action-icon"
                />
                {{ player.is_active ? 'Archiver' : 'Réactiver' }}
              </button>
              <template v-if="player.appearances === 0">
                <div class="sheet-divider" />
                <button class="sheet-action sheet-action--danger" @click="mode = 'confirm-delete'">
                  <UIcon name="i-heroicons-trash" class="sheet-action-icon" />
                  Supprimer définitivement
                </button>
              </template>
            </div>

            <!-- Confirm Archive step -->
            <div v-else-if="mode === 'confirm-archive'" key="confirm-archive" class="sheet-confirm">
              <p class="sheet-confirm-text">
                <template v-if="player.is_active">
                  Voulez-vous archiver <strong>{{ player.name }}</strong> ?<br>
                  Le joueur ne sera plus proposé lors de la création de séances, mais ses statistiques seront conservées.
                </template>
                <template v-else>
                  Voulez-vous réactiver <strong>{{ player.name }}</strong> ?
                </template>
              </p>
              <div class="sheet-confirm-btns">
                <button class="btn-outline" @click="closeSheet">Annuler</button>
                <button class="btn-archive" :disabled="isSubmitting" @click="handleArchive">
                  {{ isSubmitting ? '…' : (player.is_active ? 'Archiver' : 'Réactiver') }}
                </button>
              </div>
            </div>

            <!-- Confirm Delete step -->
            <div v-else-if="mode === 'confirm-delete'" key="confirm-delete" class="sheet-confirm">
              <template v-if="player.appearances === 0">
                <p class="sheet-confirm-text">
                  Supprimer définitivement <strong>{{ player.name }}</strong> ?<br>
                  Cette action est irréversible.
                </p>
                <div class="sheet-confirm-btns">
                  <button class="btn-outline" @click="closeSheet">Annuler</button>
                  <button class="btn-danger" :disabled="isSubmitting" @click="handleDelete">
                    {{ isSubmitting ? '…' : 'Supprimer' }}
                  </button>
                </div>
              </template>
              <template v-else>
                <p class="sheet-confirm-text">
                  <strong>{{ player.name }}</strong> a déjà participé à {{ player.appearances }} séance(s).<br>
                  Il ne peut pas être supprimé mais vous pouvez l'archiver.
                </p>
                <div class="sheet-confirm-btns">
                  <button class="btn-outline" @click="closeSheet">Annuler</button>
                  <button class="btn-archive" :disabled="isSubmitting" @click="handleArchive">
                    {{ isSubmitting ? '…' : 'Archiver' }}
                  </button>
                </div>
              </template>
            </div>
          </Transition>

          <button class="sheet-close-btn" @click="closeSheet">Fermer</button>
        </div>
      </div>
    </Transition>
  </Teleport>
</template>

<script setup lang="ts">
import { ref, watch } from 'vue'
import type { PlayerStats } from '~/types'
import { usePlayers } from '~/composables/usePlayers'

export type SheetMode = 'menu' | 'confirm-archive' | 'confirm-delete'

const props = defineProps<{
  player: PlayerStats | null
  initialMode?: SheetMode
}>()

const emit = defineEmits<{
  (e: 'close'): void
  (e: 'edit'): void
  (e: 'updated'): void
}>()

const { toggleArchivePlayer, deletePlayer } = usePlayers()
const mode = ref<SheetMode>('menu')
const isSubmitting = ref(false)

watch(
  [() => props.player, () => props.initialMode],
  ([p, m]) => {
    if (p) {
      mode.value = m || 'menu'
      isSubmitting.value = false
    }
  },
  { immediate: true }
)

function initials(name: string): string {
  const parts = name.trim().split(/\s+/)
  return parts.length >= 2
    ? (parts[0][0] + parts[1][0]).toUpperCase()
    : name.slice(0, 2).toUpperCase()
}

function closeSheet() {
  mode.value = 'menu'
  emit('close')
}

async function handleArchive() {
  if (!props.player) return
  isSubmitting.value = true
  try {
    await toggleArchivePlayer(props.player.player_id, props.player.is_active === 1)
    emit('updated')
    closeSheet()
  } catch (err) {
    console.error('Archive error:', err)
  } finally {
    isSubmitting.value = false
  }
}

async function handleDelete() {
  if (!props.player) return
  isSubmitting.value = true
  try {
    await deletePlayer(props.player.player_id)
    emit('updated')
    closeSheet()
  } catch (err) {
    console.error('Delete error:', err)
  } finally {
    isSubmitting.value = false
  }
}
</script>

<style scoped>
.sheet-overlay {
  position: fixed;
  inset: 0;
  z-index: 100;
  background: rgba(0, 0, 0, 0.55);
  display: flex;
  align-items: flex-end;
}

.sheet-panel {
  width: 100%;
  max-width: 480px;
  margin: 0 auto;
  background: var(--surface);
  border-top: 1px solid var(--hairline);
  border-radius: 20px 20px 0 0;
  padding: 12px 20px calc(20px + env(safe-area-inset-bottom, 0px));
}

.sheet-handle {
  width: 36px;
  height: 4px;
  background: var(--hairline-2);
  border-radius: 2px;
  margin: 0 auto 20px;
}

.sheet-header {
  display: flex;
  align-items: center;
  gap: 12px;
  padding-bottom: 16px;
  border-bottom: 1px solid var(--hairline);
  margin-bottom: 4px;
}

.sheet-avatar {
  width: 40px;
  height: 40px;
  border-radius: 10px;
  background: var(--surface-2);
  display: flex;
  align-items: center;
  justify-content: center;
  font-family: 'Instrument Sans', system-ui, sans-serif;
  font-size: 14px;
  font-weight: 600;
  color: var(--text-strong);
  flex-shrink: 0;
}

.sheet-player-name {
  font-family: 'Instrument Sans', system-ui, sans-serif;
  font-size: 15px;
  font-weight: 600;
  color: var(--text);
}

.sheet-player-nick {
  font-family: 'Instrument Sans', system-ui, sans-serif;
  font-size: 13px;
  color: var(--text-muted);
  margin-top: 1px;
}

.sheet-menu {
  display: flex;
  flex-direction: column;
}

.sheet-action {
  display: flex;
  align-items: center;
  gap: 12px;
  height: 52px;
  width: 100%;
  background: none;
  border: none;
  font-family: 'Instrument Sans', system-ui, sans-serif;
  font-size: 15px;
  font-weight: 500;
  color: var(--text);
  cursor: pointer;
  text-align: left;
  padding: 0;
  transition: opacity 0.12s;
}

.sheet-action:active { opacity: 0.55; }

.sheet-action--danger { color: var(--danger-text); }
.sheet-action--danger .sheet-action-icon { color: var(--danger-text); }

.sheet-action-icon {
  width: 20px;
  height: 20px;
  color: var(--text-muted);
  flex-shrink: 0;
}

.sheet-divider {
  height: 1px;
  background: var(--hairline);
}

/* Confirm steps */
.sheet-confirm { padding: 8px 0 16px; }

.sheet-confirm-text {
  font-family: 'Instrument Sans', system-ui, sans-serif;
  font-size: 14px;
  line-height: 1.55;
  color: var(--text);
  margin: 0 0 16px;
}

.sheet-confirm-text strong {
  color: var(--text-strong);
}

.sheet-confirm-btns {
  display: flex;
  gap: 10px;
}

.btn-outline,
.btn-archive,
.btn-danger {
  flex: 1;
  height: 48px;
  border-radius: 10px;
  font-family: 'Instrument Sans', system-ui, sans-serif;
  font-size: 15px;
  font-weight: 600;
  cursor: pointer;
  border: none;
  transition: opacity 0.12s;
}

.btn-outline {
  background: var(--surface-2);
  color: var(--text);
}

.btn-archive {
  background: var(--team-a);
  color: var(--ground);
}

.btn-danger {
  background: var(--danger-solid);
  color: #fff;
}

.btn-outline:disabled,
.btn-archive:disabled,
.btn-danger:disabled { opacity: 0.45; pointer-events: none; }

.sheet-close-btn {
  width: 100%;
  height: 52px;
  margin-top: 10px;
  background: var(--surface-2);
  border: none;
  border-radius: 12px;
  font-family: 'Instrument Sans', system-ui, sans-serif;
  font-size: 15px;
  font-weight: 600;
  color: var(--text);
  cursor: pointer;
  transition: opacity 0.12s;
}

.sheet-close-btn:active { opacity: 0.6; }

/* Sheet transition */
.sheet-enter-active,
.sheet-leave-active { transition: opacity 0.2s ease; }
.sheet-enter-active .sheet-panel,
.sheet-leave-active .sheet-panel { transition: transform 0.22s ease; }
.sheet-enter-from,
.sheet-leave-to { opacity: 0; }
.sheet-enter-from .sheet-panel,
.sheet-leave-to .sheet-panel { transform: translateY(100%); }

/* Fade transition */
.fade-enter-active,
.fade-leave-active { transition: opacity 0.14s ease; }
.fade-enter-from,
.fade-leave-to { opacity: 0; }
</style>
