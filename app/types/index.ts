export type SessionStatus = 'DRAFT' | 'CLOSED'
export type SplitMode = 'RANDOM' | 'RANDOM_ADJUSTED' | 'MANUAL'
export type SessionResult = 'A' | 'B' | 'DRAW'
export type Team = 'A' | 'B'
export type EligibilityMode = 'PERCENT' | 'SESSIONS'
export type DefaultFormat = '4v4' | '5v5' | '6v6'

export interface Player {
  id: string
  name: string
  nickname?: string | null
  avatar_url?: string | null
  is_active: number // 0 or 1
  created_at: string
  updated_at: string
}

export interface Session {
  id: string
  played_at: string
  status: SessionStatus
  split_mode: SplitMode
  allow_uneven_teams: number // 0 or 1
  is_ranked: number // 0 or 1
  score_a?: number | null
  score_b?: number | null
  result?: SessionResult | null
  unassigned_goals_a: number
  unassigned_goals_b: number
  notes?: string | null
  created_at: string
  updated_at: string
}

export interface Participation {
  id: string
  session_id: string
  player_id: string
  team: Team
  goals: number
  assists: number
  yellow_cards: number
  red_cards: number
  created_at: string
  updated_at: string
}

export interface PlayerStats {
  player_id: string
  name: string
  nickname?: string | null
  is_active: number
  played: number
  wins: number
  draws: number
  losses: number
  points: number
  points_per_match: number
  win_rate: number
  appearances: number
  goals: number
  assists: number
  yellow_cards: number
  red_cards: number
  last_played_at?: string | null
  is_eligible: number
  missing_sessions: number
}

export interface SessionSummary {
  session_id: string
  played_at: string
  status: SessionStatus
  split_mode: SplitMode
  is_ranked: number
  allow_uneven_teams: number
  score_a?: number | null
  score_b?: number | null
  result?: SessionResult | null
  size_a: number
  size_b: number
  attendance: number
  format: string // e.g. "5v5"
  accounted_goals_a: number
  accounted_goals_b: number
  has_goal_mismatch: number
}

/** Typed view over the `settings` key/value table (SPEC-08). */
export interface Settings {
  group_name: string
  default_format: DefaultFormat
  default_is_ranked: boolean
  eligibility_mode: EligibilityMode
  /** Percentage (0–100) when mode is PERCENT, a session count when SESSIONS. */
  eligibility_value: number
  onboarding_completed: boolean
}

export interface EligibilityThreshold {
  required_raw: number
  /** Rounded up: a player needs at least this many ranked sessions. */
  required_sessions: number
}

export interface GroupTotals {
  sessions_played: number
  ranked_sessions: number
  active_players: number
  total_players: number
  assigned_goals: number
  assists: number
  yellow_cards: number
  red_cards: number
  total_goals: number
  goals_per_session: number
}

// -- Lot 2: Session composition --

export interface TeamAssignment {
  id: string // participation id
  player_id: string
  name: string
  nickname?: string | null
  team: Team
  goals: number
  assists: number
  yellow_cards: number
  red_cards: number
}

export interface SessionDraft {
  id: string
  played_at: string
  status: SessionStatus
  split_mode: SplitMode
  allow_uneven_teams: boolean
  is_ranked: boolean
  notes?: string | null
}

export interface AttendeePlayer {
  id: string
  name: string
  nickname?: string | null
  is_active: number
  selected: boolean
}

export interface ParticipationStats {
  goals: number
  assists: number
  yellow_cards: number
  red_cards: number
}

export interface SessionClosePayload {
  sessionId: string
  scoreA: number
  scoreB: number
  unassignedGoalsA: number
  unassignedGoalsB: number
  participations: {
    id: string
    goals: number
    assists: number
    yellowCards: number
    redCards: number
  }[]
}
