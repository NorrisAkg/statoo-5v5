<script setup lang="ts">
import { useTheme } from '~/composables/useTheme'
import type { ThemeMode } from '~/composables/useTheme'

const { mode, setMode } = useTheme()

const OPTIONS: { id: ThemeMode; label: string }[] = [
  { id: 'system', label: 'Système' },
  { id: 'light', label: 'Clair' },
  { id: 'dark', label: 'Sombre' },
]
</script>

<template>
  <div class="space-y-5 p-4">
    <div class="flex items-center space-x-2">
      <NuxtLink to="/" class="text-text-muted hover:text-text">
        <UIcon name="i-heroicons-arrow-left" class="w-5 h-5" />
      </NuxtLink>
      <h1 class="font-display text-2xl font-bold text-text">Réglages</h1>
    </div>

    <!-- Backup Group -->
    <div class="p-4 rounded-lg bg-surface border border-hairline space-y-3">
      <div class="text-[11px] font-semibold uppercase text-text-muted tracking-wider">Sauvegarde</div>
      <div class="flex items-center justify-between text-sm">
        <span class="text-text-muted">Dernière sauvegarde</span>
        <span class="text-text font-medium">Il y a 2 jours</span>
      </div>
      <button class="w-full h-11 rounded-md bg-surface-2 border border-hairline text-text-strong font-medium text-sm hover:bg-hairline transition-colors">
        Sauvegarder maintenant
      </button>
      <button class="w-full text-left text-sm text-text-muted hover:text-text-strong pt-1">
        Restaurer une sauvegarde →
      </button>
    </div>

    <!-- Appearance Group -->
    <div class="p-4 rounded-lg bg-surface border border-hairline space-y-3">
      <div class="text-[11px] font-semibold uppercase text-text-muted tracking-wider">Apparence</div>

      <div
        class="grid grid-cols-3 gap-0.75 rounded-md bg-surface-2 p-0.75"
        role="radiogroup"
        aria-label="Thème"
      >
        <button
          v-for="option in OPTIONS"
          :key="option.id"
          type="button"
          role="radio"
          :aria-checked="mode === option.id"
          class="flex h-9 flex-col items-center justify-center gap-0.75 rounded text-[13px]"
          :class="mode === option.id
            ? 'bg-surface font-semibold text-text'
            : 'font-medium text-text-muted'"
          @click="setMode(option.id)"
        >
          <span>{{ option.label }}</span>
          <span v-if="mode === option.id" class="h-0.5 w-6 bg-team-a" />
        </button>
      </div>

      <p class="text-xs text-text-muted">
        « Système » suit le réglage clair ou sombre du téléphone.
      </p>
    </div>

    <!-- Data Group -->
    <div class="p-4 rounded-lg bg-surface border border-hairline space-y-3">
      <div class="text-[11px] font-semibold uppercase text-text-muted tracking-wider">Données</div>
      <div class="flex justify-between text-sm">
        <span class="text-text-muted">Version du schéma</span>
        <span class="font-display text-text">1</span>
      </div>
    </div>

    <!-- About Group -->
    <div class="p-4 rounded-lg bg-surface border border-hairline space-y-2">
      <div class="text-[11px] font-semibold uppercase text-text-muted tracking-wider">À propos</div>
      <div class="text-sm text-text-strong font-medium">Statoo 1.0.0</div>
      <div class="text-xs text-text-muted">
        Application personnelle. Aucune donnée ne quitte l'appareil en dehors des sauvegardes.
      </div>
    </div>
  </div>
</template>
