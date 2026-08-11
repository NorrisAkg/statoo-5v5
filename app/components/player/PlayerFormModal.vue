<script setup lang="ts">
import { ref, watch, computed } from 'vue'
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
  },
  { immediate: true }
)

const hasDuplicateName = computed(() => {
  if (!name.value.trim()) return false
  return checkDuplicateName(name.value, props.playerToEdit?.player_id)
})

function close() {
  emit('update:modelValue', false)
}

async function handleSubmit() {
  if (!name.value.trim() || isSubmitting.value) return
  isSubmitting.value = true
  try {
    if (props.playerToEdit) {
      await updatePlayer(props.playerToEdit.player_id, {
        name: name.value,
        nickname: nickname.value,
      })
    } else {
      await createPlayer({
        name: name.value,
        nickname: nickname.value,
      })
    }
    emit('saved')
    close()
  } catch (err) {
    console.error('Error saving player:', err)
  } finally {
    isSubmitting.value = false
  }
}
</script>

<template>
  <!-- Hand-rolled bottom sheet rather than UModal: the Nuxt UI shell draws its
       backdrop and panel from the literal palettes, which do not follow the
       light theme. Same pattern as DrawConfirmModal, and closer to screen 4. -->
  <Teleport to="body">
    <Transition name="sheet">
      <div
        v-if="modelValue"
        class="fixed inset-0 z-100 flex items-end bg-scrim"
        @click.self="close"
      >
        <div
          class="w-full max-w-120 mx-auto p-5 bg-surface border-t border-hairline rounded-t-2xl space-y-4"
          role="dialog"
          aria-modal="true"
        >
          <!-- Top Drag Handle -->
          <div class="w-9 h-1 bg-hairline-2 rounded-full mx-auto mb-5" />

          <h3 class="font-display text-xl font-bold text-text">
            {{ playerToEdit ? 'Modifier le joueur' : 'Nouveau joueur' }}
          </h3>

          <form @submit.prevent="handleSubmit" class="space-y-4">
            <!-- Nom Field -->
            <div class="space-y-1">
              <label class="text-xs font-semibold uppercase text-text-muted tracking-wider">
                Nom <span class="text-accent-text">*</span>
              </label>
              <input
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
            <div class="pt-4 flex flex-col space-y-2">
              <!-- Ghost Cancel button above -->
              <button
                type="button"
                @click="close"
                class="w-full h-[52px] rounded-md border border-hairline text-text-strong font-medium text-base hover:bg-surface-2 transition-colors"
              >
                Annuler
              </button>
              <!-- Primary Submit button below -->
              <button
                type="submit"
                :disabled="!name.trim() || isSubmitting"
                class="w-full h-[56px] rounded-md bg-team-a text-on-accent font-bold text-base hover:bg-team-a-press transition-colors disabled:opacity-50 disabled:pointer-events-none cursor-pointer"
              >
                {{ isSubmitting ? 'Enregistrement...' : 'Enregistrer' }}
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
