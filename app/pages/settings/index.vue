<script setup lang="ts">
</script>

<template>
  <div class="space-y-5">
    <div class="flex items-center space-x-2">
      <NuxtLink to="/" class="text-pitch-300 hover:text-pitch-50">
        <UIcon name="i-heroicons-arrow-left" class="w-5 h-5" />
      </NuxtLink>
      <h1 class="font-display text-2xl font-bold text-pitch-50">Réglages</h1>
    </div>

    <!-- Backup Group -->
    <div class="p-4 rounded-lg bg-pitch-900 border border-pitch-800 space-y-3">
      <div class="text-[11px] font-semibold uppercase text-pitch-400 tracking-wider">Sauvegarde</div>
      <div class="flex items-center justify-between text-sm">
        <span class="text-pitch-300">Dernière sauvegarde</span>
        <span class="text-pitch-50 font-medium">Il y a 2 jours</span>
      </div>
      <button class="w-full h-11 rounded-md bg-pitch-800 border border-pitch-700 text-pitch-100 font-medium text-sm hover:bg-pitch-700 transition-colors">
        Sauvegarder maintenant
      </button>
      <button class="w-full text-left text-sm text-pitch-300 hover:text-pitch-100 pt-1">
        Restaurer une sauvegarde →
      </button>
    </div>

    <!-- Data Group -->
    <div class="p-4 rounded-lg bg-pitch-900 border border-pitch-800 space-y-3">
      <div class="text-[11px] font-semibold uppercase text-pitch-400 tracking-wider">Données</div>
      <div class="flex justify-between text-sm">
        <span class="text-pitch-300">Version du schéma</span>
        <span class="font-display text-pitch-50">1</span>
      </div>
    </div>

    <!-- About Group -->
    <div class="p-4 rounded-lg bg-pitch-900 border border-pitch-800 space-y-2">
      <div class="text-[11px] font-semibold uppercase text-pitch-400 tracking-wider">À propos</div>
      <div class="text-sm text-pitch-100 font-medium">Statoo 1.0.0</div>
      <div class="text-xs text-pitch-300">
        Application personnelle. Aucune donnée ne quitte l'appareil en dehors des sauvegardes.
      </div>
    </div>
  </div>
</template>
