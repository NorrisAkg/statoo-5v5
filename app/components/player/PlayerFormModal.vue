<script setup lang="ts">
import { ref, watch, computed, nextTick } from 'vue'
import { usePlayers } from '~/composables/usePlayers'
import type { PlayerStats } from '~/types'

const props = defineProps<{
  modelValue: boolean
  playerToEdit?: PlayerStats | null
}>()

const emit = defineEmits<{
  (e: 'update:modelValue', value: boolean): void
  (e: 'saved'): void
}>()

const { createPlayer, updatePlayer, checkDuplicateName } = usePlayers()

const name = ref('')
const nickname = ref('')
const isSubmitting = ref(false)
const successMessage = ref('')
const nameInputRef = ref<HTMLInputElement | null>(null)

watch(
  () => props.playerToEdit,
  (val) => {
    if (val) {
      name.value = val.name || ''
      nickname.value = val.nickname || ''
    } else {
      name.value = ''
      nickname.value = ''
    }
    successMessage.value = ''
  },
  { immediate: true }
)

watch(
  () => props.modelValue,
  (isOpen) => {
    if (isOpen) {
      name.value = props.playerToEdit?.name || ''
      nickname.value = props.playerToEdit?.nickname || ''
      successMessage.value = ''
      nextTick(() => {
        nameInputRef.value?.focus()
      })
    }
  }
)

const hasDuplicateName = computed(() => {
  if (!name.value.trim()) return false
  return checkDuplicateName(name.value, props.playerToEdit?.player_id)
})

function close() {
  successMessage.value = ''
  emit('update:modelValue', false)
}

async function savePlayer(keepOpen = false) {
  if (!name.value.trim() || isSubmitting.value) return
  isSubmitting.value = true
  try {
    const savedName = name.value.trim()
    if (props.playerToEdit) {
      await updatePlayer(props.playerToEdit.player_id, {
        name: savedName,
        nickname: nickname.value.trim() || undefined,
      })
    } else {
      await createPlayer({
        name: savedName,
        nickname: nickname.value.trim() || undefined,
      })
    }
    emit('saved')

    if (keepOpen) {
      name.value = ''
      nickname.value = ''
      successMessage.value = `Joueur « ${savedName} » ajouté avec succès !`
      setTimeout(() => {
        if (successMessage.value.includes(savedName)) {
          successMessage.value = ''
        }
      }, 3000)
      nextTick(() => {
        nameInputRef.value?.focus()
      })
    } else {
      close()
    }
  } catch (err) {
    console.error('Error saving player:', err)
  } finally {
    isSubmitting.value = false
  }
}

function handleSubmit() {
  savePlayer(false)
}

function handleSaveAndAddAnother() {
  savePlayer(true)
}
</script>

<template>
  <Teleport to="body">
    <Transition name="sheet">
      <div
        v-if="modelValue"
        class="fixed inset-0 z-100 flex items-end bg-scrim"
        @click.self="close"
      >
        <div
          class="w-full max-w-120 mx-auto p-5 bg-surface border-t border-hairline rounded-t-2xl space-y-4"
          :style="{ paddingBottom: 'calc(20px + env(safe-area-inset-bottom, 0px))' }"
          role="dialog"
          aria-modal="true"
        >
          <!-- Top Drag Handle -->
          <div class="w-9 h-1 bg-hairline-2 rounded-full mx-auto mb-5" />

          <h3 class="font-display text-xl font-bold text-text">
            {{ playerToEdit ? 'Modifier le joueur' : 'Nouveau joueur' }}
          </h3>

          <!-- Success Notification Banner -->
          <div
            v-if="successMessage"
            class="px-3 py-2.5 bg-surface-2 border border-team-a/40 rounded-lg text-team-a text-xs font-semibold flex items-center justify-between transition-all"
          >
            <span>✓ {{ successMessage }}</span>
          </div>

          <form @submit.prevent="handleSubmit" class="space-y-4">
            <!-- Nom Field -->
            <div class="space-y-1">
              <label class="text-xs font-semibold uppercase text-text-muted tracking-wider">
                Nom <span class="text-accent-text">*</span>
              </label>
              <input
                ref="nameInputRef"
                v-model="name"
                type="text"
                required
                placeholder="Ex: Karim"
                class="w-full h-[52px] px-4 rounded-md bg-surface-2 border border-hairline text-text placeholder-text-muted focus:outline-none focus:border-accent-text font-sans text-base transition-colors"
              />
              <!-- Duplicate name non-blocking warning -->
              <p v-if="hasDuplicateName" class="text-[13px] text-danger-text pt-1">
                Un joueur porte déjà ce nom. Vous pouvez continuer.
              </p>
            </div>

            <!-- Surnom Field -->
            <div class="space-y-1">
              <label class="text-xs font-semibold uppercase text-text-muted tracking-wider">
                Surnom (optionnel)
              </label>
              <input
                v-model="nickname"
                type="text"
                placeholder="Ex: Kaka"
                class="w-full h-[52px] px-4 rounded-md bg-surface-2 border border-hairline text-text placeholder-text-muted focus:outline-none focus:border-accent-text font-sans text-base transition-colors"
              />
            </div>

            <!-- Bottom Action Buttons Stack -->
            <div class="pt-2 flex flex-col space-y-2">
              <!-- Save and Add Another (creation mode only) -->
              <button
                v-if="!playerToEdit"
                type="button"
                :disabled="!name.trim() || isSubmitting"
                @click="handleSaveAndAddAnother"
                class="w-full h-[48px] rounded-md bg-surface-2 border border-hairline text-text-strong font-semibold text-base hover:bg-surface-3 transition-colors disabled:opacity-50 disabled:pointer-events-none cursor-pointer"
              >
                {{ isSubmitting ? 'Enregistrement…' : 'Enregistrer et ajouter un autre' }}
              </button>

              <!-- Primary Submit button -->
              <button
                type="submit"
                :disabled="!name.trim() || isSubmitting"
                class="w-full h-[52px] rounded-md bg-team-a text-on-accent font-bold text-base hover:bg-team-a-press transition-colors disabled:opacity-50 disabled:pointer-events-none cursor-pointer"
              >
                {{ isSubmitting ? 'Enregistrement…' : (playerToEdit ? 'Enregistrer' : 'Enregistrer et fermer') }}
              </button>

              <!-- Cancel button -->
              <button
                type="button"
                @click="close"
                class="w-full h-[44px] rounded-md border border-hairline text-text-muted font-medium text-sm hover:bg-surface-2 transition-colors cursor-pointer"
              >
                {{ successMessage ? 'Terminer' : 'Annuler' }}
              </button>
            </div>
          </form>
        </div>
      </div>
    </Transition>
  </Teleport>
</template>

<style scoped>
.sheet-enter-active,
.sheet-leave-active {
  transition: opacity 0.18s ease;
}

.sheet-enter-active > div,
.sheet-leave-active > div {
  transition: transform 0.18s ease;
}

.sheet-enter-from,
.sheet-leave-to {
  opacity: 0;
}

.sheet-enter-from > div,
.sheet-leave-to > div {
  transform: translateY(100%);
}
</style>
