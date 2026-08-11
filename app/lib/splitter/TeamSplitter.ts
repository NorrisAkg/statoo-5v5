// Team splitter interface
export interface TeamSplitter {
  split(players: { id: string; name: string }[]): { teamA: string[]; teamB: string[] }
}
