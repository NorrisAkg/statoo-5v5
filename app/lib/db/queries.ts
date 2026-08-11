import { SQLiteDBConnection } from '@capacitor-community/sqlite'
import type { Player, PlayerStats, Session, Participation, TeamAssignment } from '~/types'

export async function fetchAllPlayers(db: SQLiteDBConnection): Promise<Player[]> {
  const res = await db.query('SELECT * FROM players ORDER BY is_active DESC, name ASC;')
  return (res.values || []) as Player[]
}

export async function fetchAllPlayerStats(db: SQLiteDBConnection): Promise<PlayerStats[]> {
  const res = await db.query('SELECT * FROM v_player_stats ORDER BY is_active DESC, name ASC;')
  return (res.values || []) as PlayerStats[]
}

export async function fetchPlayerStatsById(db: SQLiteDBConnection, id: string): Promise<PlayerStats | null> {
  const res = await db.query('SELECT * FROM v_player_stats WHERE player_id = ?;', [id])
  if (res.values && res.values.length > 0) {
    return res.values[0] as PlayerStats
  }
  return null
}

export async function insertPlayer(
  db: SQLiteDBConnection,
  player: { id: string; name: string; nickname?: string | null; avatar_url?: string | null }
): Promise<void> {
  const now = new Date().toISOString()
  await db.run(
    `INSERT INTO players (id, name, nickname, avatar_url, is_active, created_at, updated_at)
     VALUES (?, ?, ?, ?, 1, ?, ?);`,
    [player.id, player.name.trim(), player.nickname?.trim() || null, player.avatar_url || null, now, now]
  )
}

export async function updatePlayer(
  db: SQLiteDBConnection,
  id: string,
  data: { name: string; nickname?: string | null; avatar_url?: string | null }
): Promise<void> {
  const now = new Date().toISOString()
  await db.run(
    `UPDATE players SET name = ?, nickname = ?, avatar_url = ?, updated_at = ? WHERE id = ?;`,
    [data.name.trim(), data.nickname?.trim() || null, data.avatar_url || null, now, id]
  )
}

export async function setPlayerActiveStatus(
  db: SQLiteDBConnection,
  id: string,
  isActive: boolean
): Promise<void> {
  const now = new Date().toISOString()
  await db.run(
    `UPDATE players SET is_active = ?, updated_at = ? WHERE id = ?;`,
    [isActive ? 1 : 0, now, id]
  )
}

export async function deletePlayerById(db: SQLiteDBConnection, id: string): Promise<void> {
  await db.run(`DELETE FROM players WHERE id = ?;`, [id])
}

export async function getPlayerParticipationCount(db: SQLiteDBConnection, id: string): Promise<number> {
  const res = await db.query(`SELECT COUNT(*) as count FROM participations WHERE player_id = ?;`, [id])
  if (res.values && res.values.length > 0) {
    return Number(res.values[0].count)
  }
  return 0
}

export async function fetchPlayerMatchHistory(db: SQLiteDBConnection, playerId: string): Promise<any[]> {
  const sql = `
    SELECT
      p.id as participation_id,
      p.session_id,
      p.team,
      p.goals,
      p.assists,
      p.yellow_cards,
      p.red_cards,
      s.played_at,
      s.status,
      s.is_ranked,
      s.score_a,
      s.score_b,
      s.result,
      sum.format
    FROM participations p
    JOIN sessions s ON s.id = p.session_id
    LEFT JOIN v_session_summary sum ON sum.session_id = s.id
    WHERE p.player_id = ? AND s.status = 'CLOSED'
    ORDER BY s.played_at DESC;
  `
  const res = await db.query(sql, [playerId])
  return res.values || []
}

// ---------------------------------------------------------------------------
// Sessions
// ---------------------------------------------------------------------------

export async function fetchAllSessions(db: SQLiteDBConnection): Promise<Session[]> {
  const res = await db.query(
    `SELECT * FROM sessions ORDER BY played_at DESC;`
  )
  return (res.values || []) as Session[]
}

export async function fetchSessionById(db: SQLiteDBConnection, id: string): Promise<Session | null> {
  const res = await db.query(`SELECT * FROM sessions WHERE id = ?;`, [id])
  if (res.values && res.values.length > 0) {
    return res.values[0] as Session
  }
  return null
}

export async function insertSession(
  db: SQLiteDBConnection,
  session: {
    id: string
    played_at: string
    allow_uneven_teams: boolean
    is_ranked: boolean
    notes?: string | null
  }
): Promise<void> {
  const now = new Date().toISOString()
  await db.run(
    `INSERT INTO sessions (id, played_at, status, split_mode, allow_uneven_teams, is_ranked, notes, created_at, updated_at)
     VALUES (?, ?, 'DRAFT', 'MANUAL', ?, ?, ?, ?, ?);`,
    [
      session.id,
      session.played_at,
      session.allow_uneven_teams ? 1 : 0,
      session.is_ranked ? 1 : 0,
      session.notes || null,
      now,
      now,
    ]
  )
}

export async function updateSessionSplitMode(
  db: SQLiteDBConnection,
  id: string,
  mode: 'RANDOM' | 'RANDOM_ADJUSTED' | 'MANUAL'
): Promise<void> {
  const now = new Date().toISOString()
  await db.run(
    `UPDATE sessions SET split_mode = ?, updated_at = ? WHERE id = ?;`,
    [mode, now, id]
  )
}

// ---------------------------------------------------------------------------
// Participations
// ---------------------------------------------------------------------------

export async function fetchParticipationsBySession(
  db: SQLiteDBConnection,
  sessionId: string
): Promise<TeamAssignment[]> {
  const res = await db.query(
    `SELECT
       p.player_id,
       pl.name,
       pl.nickname,
       p.team,
       p.goals,
       p.assists,
       p.yellow_cards,
       p.red_cards
     FROM participations p
     JOIN players pl ON pl.id = p.player_id
     WHERE p.session_id = ?
     ORDER BY p.team ASC, pl.name ASC;`,
    [sessionId]
  )
  return (res.values || []) as TeamAssignment[]
}

export async function insertParticipation(
  db: SQLiteDBConnection,
  data: { id: string; session_id: string; player_id: string; team: 'A' | 'B' }
): Promise<void> {
  const now = new Date().toISOString()
  await db.run(
    `INSERT INTO participations (id, session_id, player_id, team, goals, assists, yellow_cards, red_cards, created_at, updated_at)
     VALUES (?, ?, ?, ?, 0, 0, 0, 0, ?, ?);`,
    [data.id, data.session_id, data.player_id, data.team, now, now]
  )
}

export async function deleteParticipationsBySession(
  db: SQLiteDBConnection,
  sessionId: string
): Promise<void> {
  await db.run(`DELETE FROM participations WHERE session_id = ?;`, [sessionId])
}

export async function swapPlayerTeam(
  db: SQLiteDBConnection,
  sessionId: string,
  playerId: string,
  newTeam: 'A' | 'B'
): Promise<void> {
  const now = new Date().toISOString()
  await db.run(
    `UPDATE participations SET team = ?, updated_at = ? WHERE session_id = ? AND player_id = ?;`,
    [newTeam, now, sessionId, playerId]
  )
}

// ---------------------------------------------------------------------------
// SPEC-04: Match Stats & Closure
// ---------------------------------------------------------------------------

/** Fetch participations for a session including the participation id. */
export async function fetchParticipationsBySessionWithId(
  db: SQLiteDBConnection,
  sessionId: string
): Promise<import('~/types').TeamAssignment[]> {
  const res = await db.query(
    `SELECT
       p.id,
       p.player_id,
       pl.name,
       pl.nickname,
       p.team,
       p.goals,
       p.assists,
       p.yellow_cards,
       p.red_cards
     FROM participations p
     JOIN players pl ON pl.id = p.player_id
     WHERE p.session_id = ?
     ORDER BY p.team ASC, pl.name ASC;`,
    [sessionId]
  )
  return (res.values || []) as import('~/types').TeamAssignment[]
}

/** Fetch the v_session_summary row for a session. */
export async function fetchSessionSummary(
  db: SQLiteDBConnection,
  sessionId: string
): Promise<import('~/types').SessionSummary | null> {
  const res = await db.query(
    `SELECT * FROM v_session_summary WHERE session_id = ?;`,
    [sessionId]
  )
  if (res.values && res.values.length > 0) {
    return res.values[0] as import('~/types').SessionSummary
  }
  return null
}

/** Update individual stats for a participation row. */
export async function updateParticipationStats(
  db: SQLiteDBConnection,
  participationId: string,
  stats: Partial<{ goals: number; assists: number; yellow_cards: number; red_cards: number }>
): Promise<void> {
  const now = new Date().toISOString()
  const sets: string[] = []
  const values: (number | string)[] = []

  if (stats.goals !== undefined) { sets.push('goals = ?'); values.push(stats.goals) }
  if (stats.assists !== undefined) { sets.push('assists = ?'); values.push(stats.assists) }
  if (stats.yellow_cards !== undefined) { sets.push('yellow_cards = ?'); values.push(stats.yellow_cards) }
  if (stats.red_cards !== undefined) { sets.push('red_cards = ?'); values.push(stats.red_cards) }

  if (sets.length === 0) return
  values.push(now, participationId)
  await db.run(
    `UPDATE participations SET ${sets.join(', ')}, updated_at = ? WHERE id = ?;`,
    values
  )
}

/** Update session scores and unassigned goals. */
export async function updateSessionScores(
  db: SQLiteDBConnection,
  sessionId: string,
  scoreA: number,
  scoreB: number,
  unassignedGoalsA: number,
  unassignedGoalsB: number
): Promise<void> {
  const now = new Date().toISOString()
  await db.run(
    `UPDATE sessions SET score_a = ?, score_b = ?, unassigned_goals_a = ?, unassigned_goals_b = ?, updated_at = ? WHERE id = ?;`,
    [scoreA, scoreB, unassignedGoalsA, unassignedGoalsB, now, sessionId]
  )
}

/** Derive result and close the session. */
export async function closeSession(
  db: SQLiteDBConnection,
  sessionId: string
): Promise<void> {
  const now = new Date().toISOString()
  // Derive result from current score_a / score_b
  const res = await db.query(`SELECT score_a, score_b FROM sessions WHERE id = ?;`, [sessionId])
  if (!res.values || res.values.length === 0) throw new Error('Session not found')
  const { score_a, score_b } = res.values[0]
  const result =
    score_a > score_b ? 'A' :
    score_b > score_a ? 'B' :
    'DRAW'
  await db.run(
    `UPDATE sessions SET status = 'CLOSED', result = ?, updated_at = ? WHERE id = ?;`,
    [result, now, sessionId]
  )
}

/** Reopen a closed session (set back to DRAFT, clear result). */
export async function reopenSession(
  db: SQLiteDBConnection,
  sessionId: string
): Promise<void> {
  const now = new Date().toISOString()
  await db.run(
    `UPDATE sessions SET status = 'DRAFT', result = NULL, updated_at = ? WHERE id = ?;`,
    [now, sessionId]
  )
}

/** Delete a session and its participations (cascades via FK). */
export async function deleteSession(
  db: SQLiteDBConnection,
  sessionId: string
): Promise<void> {
  await db.run(`DELETE FROM sessions WHERE id = ?;`, [sessionId])
}
