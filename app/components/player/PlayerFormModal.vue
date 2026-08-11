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
  <UModal :model-value="modelValue" @update:model-value="close">
    <template #content>
      <div class="p-5 bg-pitch-900 border border-pitch-800 rounded-t-2xl space-y-4">
        <!-- Top Drag Handle -->
        <div class="w-10 h-1 bg-pitch-700 rounded-full mx-auto mb-2" />

        <h3 class="font-display text-xl font-bold text-pitch-50">
          {{ playerToEdit ? 'Modifier le joueur' : 'Nouveau joueur' }}
        </h3>

        <form @submit.prevent="handleSubmit" class="space-y-4">
          <!-- Nom Field -->
          <div class="space-y-1">
            <label class="text-xs font-semibold uppercase text-pitch-300 tracking-wider">
              Nom <span class="text-bib-400">*</span>
            </label>
            <input
              v-model="name"
              type="text"
              required
              placeholder="Ex: Karim"
              class="w-full h-[52px] px-4 rounded-md bg-pitch-800 border border-pitch-700 text-pitch-50 placeholder-pitch-400 focus:outline-none focus:border-bib-400 font-sans text-base transition-colors"
            />
            <!-- Duplicate name non-blocking warning -->
            <p v-if="hasDuplicateName" class="text-[13px] text-flag-400 pt-1">
              Un joueur porte déjà ce nom. Vous pouvez continuer.
            </p>
          </div>

          <!-- Surnom Field -->
          <div class="space-y-1">
            <label class="text-xs font-semibold uppercase text-pitch-300 tracking-wider">
              Surnom (optionnel)
            </label>
            <input
              v-model="nickname"
              type="text"
              placeholder="Ex: Kaka"
              class="w-full h-[52px] px-4 rounded-md bg-pitch-800 border border-pitch-700 text-pitch-50 placeholder-pitch-400 focus:outline-none focus:border-bib-400 font-sans text-base transition-colors"
            />
          </div>

          <!-- Bottom Action Buttons Stack -->
          <div class="pt-4 flex flex-col space-y-2">
            <!-- Ghost Cancel button above -->
            <button
              type="button"
              @click="close"
              class="w-full h-[52px] rounded-md border border-pitch-700 text-pitch-100 font-medium text-base hover:bg-pitch-800 transition-colors"
            >
              Annuler
            </button>
            <!-- Primary Submit button below -->
            <button
              type="submit"
              :disabled="!name.trim() || isSubmitting"
              class="w-full h-[56px] rounded-md bg-bib-400 text-pitch-950 font-bold text-base hover:bg-bib-300 transition-colors disabled:opacity-50 disabled:pointer-events-none cursor-pointer"
            >
              {{ isSubmitting ? 'Enregistrement...' : 'Enregistrer' }}
            </button>
          </div>
        </form>
      </div>
    </template>
  </UModal>
</template>
