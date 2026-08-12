<script setup lang="ts">
import { useRoute } from 'vue-router'

const route = useRoute()

function isActive(path: string) {
  if (path === '/') return route.path === '/'
  return route.path.startsWith(path)
}
</script>

<template>
  <div class="min-h-screen bg-ground text-text flex justify-center">
    <!-- Mobile Frame max 480px -->
    <div class="w-full max-w-[480px] min-h-screen flex flex-col relative bg-ground shadow-2xl border-x border-surface">

      <!-- Main Content Area — clears the fixed nav, plus the iOS home indicator
           when installed as a PWA (env() is 0 everywhere else) -->
      <main class="main-scroll flex-1 overflow-y-auto">
        <slot />
      </main>

      <!-- Fixed Bottom Navigation Bar — 64px tall, exactly matching mockup. The
           safe-area inset is added as padding so the bar grows downwards rather
           than squeezing its 64px of icons. -->
      <nav
        class="bottom-nav fixed bottom-0 left-1/2 -translate-x-1/2 w-full max-w-[480px] border-t z-50"
        style="background:var(--ground); border-color:var(--hairline); display:grid; grid-template-columns:repeat(5,1fr);"
      >
        <!-- Accueil -->
        <NuxtLink
          to="/"
          class="nav-item"
          :style="isActive('/') ? 'color:var(--accent-text)' : 'color:var(--text-muted)'"
        >
          <UIcon name="i-heroicons-home" class="w-5 h-5 flex-shrink-0" />
          <span class="nav-label">Accueil</span>
        </NuxtLink>

        <!-- Joueurs -->
        <NuxtLink
          to="/players"
          class="nav-item"
          :style="isActive('/players') ? 'color:var(--accent-text)' : 'color:var(--text-muted)'"
        >
          <UIcon name="i-heroicons-user-group" class="w-5 h-5 flex-shrink-0" />
          <span class="nav-label">Joueurs</span>
        </NuxtLink>

        <!-- Séances -->
        <NuxtLink
          to="/sessions"
          class="nav-item"
          :style="isActive('/sessions') ? 'color:var(--accent-text)' : 'color:var(--text-muted)'"
        >
          <UIcon name="i-heroicons-calendar-days" class="w-5 h-5 flex-shrink-0" />
          <span class="nav-label">Séances</span>
        </NuxtLink>

        <!-- Classement -->
        <NuxtLink
          to="/standings"
          class="nav-item"
          :style="isActive('/standings') ? 'color:var(--accent-text)' : 'color:var(--text-muted)'"
        >
          <UIcon name="i-heroicons-trophy" class="w-5 h-5 flex-shrink-0" />
          <span class="nav-label">Classement</span>
        </NuxtLink>

        <!-- Stats -->
        <NuxtLink
          to="/stats"
          class="nav-item"
          :style="isActive('/stats') ? 'color:var(--accent-text)' : 'color:var(--text-muted)'"
        >
          <UIcon name="i-heroicons-chart-bar" class="w-5 h-5 flex-shrink-0" />
          <span class="nav-label">Stats</span>
        </NuxtLink>
      </nav>

    </div>
  </div>
</template>

<style scoped>
.bottom-nav {
  height: 64px;
  height: calc(64px + env(safe-area-inset-bottom, 0px));
  padding-bottom: env(safe-area-inset-bottom, 0px);
  box-sizing: border-box;
}

.main-scroll {
  padding-top: env(safe-area-inset-top, 0px);
  padding-bottom: calc(64px + env(safe-area-inset-bottom, 0px));
}

.nav-item {
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  gap: 5px;
  text-decoration: none;
  transition: color 0.15s ease;
}

.nav-label {
  font-family: 'Instrument Sans', system-ui, sans-serif;
  font-size: 11px;
  font-weight: 500;
  line-height: 1;
}

.nav-icon {
  display: flex;
  align-items: center;
  justify-content: center;
}
</style>
