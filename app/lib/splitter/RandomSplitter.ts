import type { TeamSplitter } from './TeamSplitter'

/**
 * Fisher-Yates unbiased shuffle implementation.
 * Team A always gets Math.ceil(n/2) players (≥ Team B for odd counts).
 */
export class RandomSplitter implements TeamSplitter {
  split(players: { id: string; name: string }[]): { teamA: string[]; teamB: string[] } {
    const shuffled = [...players]

    // Fisher-Yates (Knuth) shuffle — unbiased, unlike sort(() => Math.random() - 0.5)
    for (let i = shuffled.length - 1; i > 0; i--) {
      const j = Math.floor(Math.random() * (i + 1))
      ;[shuffled[i], shuffled[j]] = [shuffled[j], shuffled[i]]
    }

    const mid = Math.ceil(shuffled.length / 2)
    return {
      teamA: shuffled.slice(0, mid).map((p) => p.id),
      teamB: shuffled.slice(mid).map((p) => p.id),
    }
  }
}
