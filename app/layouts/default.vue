<script setup lang="ts">
import { useRoute } from 'vue-router'

const route = useRoute()

function isActive(path: string) {
  if (path === '/') return route.path === '/'
  return route.path.startsWith(path)
}
</script>

<template>
  <div class="min-h-screen bg-pitch-950 text-pitch-50 flex justify-center">
    <!-- Mobile Frame max 480px -->
    <div class="w-full max-w-[480px] min-h-screen flex flex-col relative bg-pitch-950 shadow-2xl border-x border-pitch-900">

      <!-- Main Content Area — pb-[64px] to clear fixed nav -->
      <main class="flex-1 pb-[64px] overflow-y-auto">
        <slot />
      </main>

      <!-- Fixed Bottom Navigation Bar — 64px, exactly matching mockup -->
      <nav
        class="fixed bottom-0 left-1/2 -translate-x-1/2 w-full max-w-[480px] h-[64px] border-t z-50"
        style="background:#0B120F; border-color:#2A3831; display:grid; grid-template-columns:repeat(5,1fr);"
      >
        <!-- Accueil — carré 2px border-radius 2px -->
        <NuxtLink
          to="/"
          class="nav-item"
          :style="isActive('/') ? 'color:#FFC94F' : 'color:#8CA096'"
        >
          <span
            class="nav-icon"
            :style="`width:18px;height:18px;border:2px solid currentColor;border-radius:2px;box-sizing:border-box;flex-shrink:0`"
          ></span>
          <span class="nav-label">Accueil</span>
        </NuxtLink>

        <!-- Joueurs — cercle 2px -->
        <NuxtLink
          to="/players"
          class="nav-item"
          :style="isActive('/players') ? 'color:#FFC94F' : 'color:#8CA096'"
        >
          <span
            class="nav-icon"
            :style="`width:18px;height:18px;border:2px solid currentColor;border-radius:9px;box-sizing:border-box;flex-shrink:0`"
          ></span>
          <span class="nav-label">Joueurs</span>
        </NuxtLink>

        <!-- Séances — losange 45° (carré tourné) -->
        <NuxtLink
          to="/sessions"
          class="nav-item"
          :style="isActive('/sessions') ? 'color:#FFC94F' : 'color:#8CA096'"
        >
          <span
            class="nav-icon"
            :style="`width:18px;height:18px;border:2px solid currentColor;box-sizing:border-box;transform:rotate(45deg);flex-shrink:0`"
          ></span>
          <span class="nav-label">Séances</span>
        </NuxtLink>

        <!-- Classement — 3 barres horizontales empilées -->
        <NuxtLink
          to="/standings"
          class="nav-item"
          :style="isActive('/standings') ? 'color:#FFC94F' : 'color:#8CA096'"
        >
          <span
            class="nav-icon"
            style="width:18px;height:18px;display:flex;flex-direction:column;justify-content:space-between;flex-shrink:0"
          >
            <span style="height:2px;background:currentColor"></span>
            <span style="height:2px;background:currentColor"></span>
            <span style="height:2px;background:currentColor"></span>
          </span>
          <span class="nav-label">Classement</span>
        </NuxtLink>

        <!-- Stats — 3 barreaux de hauteur variable (histogramme) -->
        <NuxtLink
          to="/stats"
          class="nav-item"
          :style="isActive('/stats') ? 'color:#FFC94F' : 'color:#8CA096'"
        >
          <span
            class="nav-icon"
            style="width:18px;height:18px;display:flex;align-items:flex-end;gap:3px;flex-shrink:0"
          >
            <span style="width:4px;height:8px;background:currentColor"></span>
            <span style="width:4px;height:14px;background:currentColor"></span>
            <span style="width:4px;height:11px;background:currentColor"></span>
          </span>
          <span class="nav-label">Stats</span>
        </NuxtLink>
      </nav>

    </div>
  </div>
</template>

<style scoped>
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
