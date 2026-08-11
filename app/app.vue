<script setup lang="ts">
import { onMounted } from 'vue'
import { useDb } from '~/composables/useDb'

const { isInitialized, initError, initDb } = useDb()

onMounted(async () => {
  try {
    await initDb()
  } catch (e) {
    console.error('Initialization error:', e)
  }
})
</script>

<template>
  <UApp>
    <div v-if="!isInitialized" class="min-h-screen bg-pitch-950 flex flex-col items-center justify-center p-6 text-center">
      <template v-if="initError">
        <div class="p-4 rounded-lg bg-flag-950 border border-flag-700 text-flag-300 max-w-sm">
          <h2 class="font-display font-bold text-lg mb-2">Erreur d'initialisation</h2>
          <p class="text-sm mb-4">{{ initError }}</p>
          <UButton color="neutral" variant="outline" @click="initDb">Réessayer</UButton>
        </div>
      </template>
      <template v-else>
        <UIcon name="i-heroicons-arrow-path" class="w-8 h-8 text-bib-400 animate-spin mb-3" />
        <p class="text-pitch-300 text-sm font-sans">Initialisation de la base de données...</p>
      </template>
    </div>

    <NuxtLayout v-else>
      <NuxtPage />
    </NuxtLayout>
  </UApp>
</template>
