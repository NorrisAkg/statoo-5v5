import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

class AppDatabase {
  factory AppDatabase() => instance;
  AppDatabase._internal();

  static final AppDatabase instance = AppDatabase._internal();

  Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = p.join(dbPath, 'statoo.db');

    return await openDatabase(
      path,
      version: 1,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON;');
      },
      onCreate: (db, version) async {
        await _createSchema(db);
        await _createViews(db);
        await _seedDemoData(db);
      },
      onOpen: (db) async {
        await _createViews(db);
      },
    );
  }

  Future<void> _createSchema(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS players (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        nickname TEXT,
        avatar_url TEXT,
        is_active INTEGER NOT NULL DEFAULT 1,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      );
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS sessions (
        id TEXT PRIMARY KEY,
        played_at TEXT NOT NULL,
        status TEXT NOT NULL CHECK(status IN ('DRAFT', 'CLOSED')),
        split_mode TEXT CHECK(split_mode IN ('RANDOM', 'RANDOM_ADJUSTED', 'MANUAL')),
        allow_uneven_teams INTEGER NOT NULL DEFAULT 0,
        is_ranked INTEGER NOT NULL DEFAULT 1,
        score_a INTEGER,
        score_b INTEGER,
        result TEXT CHECK(result IN ('A', 'B', 'DRAW')),
        unassigned_goals_a INTEGER DEFAULT 0,
        unassigned_goals_b INTEGER DEFAULT 0,
        notes TEXT
      );
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS participations (
        id TEXT PRIMARY KEY,
        session_id TEXT NOT NULL REFERENCES sessions(id) ON DELETE CASCADE,
        player_id TEXT NOT NULL REFERENCES players(id) ON DELETE RESTRICT,
        team TEXT NOT NULL CHECK(team IN ('A', 'B')),
        goals INTEGER NOT NULL DEFAULT 0,
        assists INTEGER NOT NULL DEFAULT 0,
        yellow_cards INTEGER NOT NULL DEFAULT 0,
        red_cards INTEGER NOT NULL DEFAULT 0,
        UNIQUE (session_id, player_id)
      );
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS meta (
        key TEXT PRIMARY KEY,
        value TEXT
      );
    ''');

    await db.execute('''
      INSERT OR REPLACE INTO meta (key, value) VALUES ('schema_version', '1');
    ''');
  }

  Future<void> _createViews(Database db) async {
    await db.execute('''
      CREATE VIEW IF NOT EXISTS v_player_match_results AS
      SELECT 
        pt.id AS participation_id,
        pt.session_id,
        pt.player_id,
        pt.team,
        pt.goals,
        pt.assists,
        pt.yellow_cards,
        pt.red_cards,
        s.is_ranked,
        s.status,
        CASE 
          WHEN s.status = 'CLOSED' AND s.is_ranked = 1 THEN
            CASE 
              WHEN s.result = 'DRAW' THEN 1
              WHEN (s.result = 'A' AND pt.team = 'A') OR (s.result = 'B' AND pt.team = 'B') THEN 3
              ELSE 0
            END
          ELSE 0
        END AS points,
        CASE 
          WHEN s.status = 'CLOSED' AND s.is_ranked = 1 AND ((s.result = 'A' AND pt.team = 'A') OR (s.result = 'B' AND pt.team = 'B')) THEN 1
          ELSE 0
        END AS is_win,
        CASE 
          WHEN s.status = 'CLOSED' AND s.is_ranked = 1 AND s.result = 'DRAW' THEN 1
          ELSE 0
        END AS is_draw,
        CASE 
          WHEN s.status = 'CLOSED' AND s.is_ranked = 1 AND ((s.result = 'A' AND pt.team = 'B') OR (s.result = 'B' AND pt.team = 'A')) THEN 1
          ELSE 0
        END AS is_loss
      FROM participations pt
      JOIN sessions s ON s.id = pt.session_id;
    ''');

    await db.execute('''
      CREATE VIEW IF NOT EXISTS v_standings AS
      WITH player_aggregates AS (
        SELECT 
          pl.id AS player_id,
          pl.name,
          pl.nickname,
          pl.avatar_url,
          pl.is_active,
          COUNT(CASE WHEN pm.status = 'CLOSED' AND pm.is_ranked = 1 THEN 1 END) AS matches_played,
          COALESCE(SUM(pm.is_win), 0) AS wins,
          COALESCE(SUM(pm.is_draw), 0) AS draws,
          COALESCE(SUM(pm.is_loss), 0) AS losses,
          COALESCE(SUM(pm.points), 0) AS points,
          COALESCE(SUM(CASE WHEN pm.status = 'CLOSED' THEN pm.goals ELSE 0 END), 0) AS goals,
          COALESCE(SUM(CASE WHEN pm.status = 'CLOSED' THEN pm.assists ELSE 0 END), 0) AS assists
        FROM players pl
        LEFT JOIN v_player_match_results pm ON pm.player_id = pl.id
        WHERE pl.is_active = 1
        GROUP BY pl.id, pl.name, pl.nickname, pl.avatar_url, pl.is_active
      )
      SELECT 
        ROW_NUMBER() OVER (ORDER BY points DESC, wins DESC, matches_played DESC, name ASC) AS rank,
        player_id,
        name,
        nickname,
        avatar_url,
        is_active,
        matches_played,
        wins,
        draws,
        losses,
        points,
        goals,
        assists
      FROM player_aggregates
      ORDER BY rank;
    ''');

    await db.execute('''
      CREATE VIEW IF NOT EXISTS v_standings_per_match AS
      WITH total_ranked AS (
        SELECT COUNT(*) as total_sessions FROM sessions WHERE status = 'CLOSED' AND is_ranked = 1
      ),
      standings_base AS (
        SELECT 
          s.*,
          tr.total_sessions,
          ROUND(CASE WHEN s.matches_played > 0 THEN CAST(s.points AS REAL) / s.matches_played ELSE 0.0 END, 2) AS points_per_match,
          CASE WHEN s.matches_played >= (CAST(tr.total_sessions AS REAL) / 2.0) THEN 1 ELSE 0 END AS is_eligible,
          MAX(0, CAST((tr.total_sessions + 1) / 2 AS INTEGER) - s.matches_played) AS missing_matches
        FROM v_standings s, total_ranked tr
      )
      SELECT 
        ROW_NUMBER() OVER (ORDER BY is_eligible DESC, points_per_match DESC, points DESC, matches_played DESC, name ASC) AS rank,
        player_id,
        name,
        nickname,
        avatar_url,
        is_active,
        matches_played,
        wins,
        draws,
        losses,
        points,
        points_per_match,
        is_eligible,
        missing_matches,
        total_sessions
      FROM standings_base
      ORDER BY rank;
    ''');

    await db.execute('''
      CREATE VIEW IF NOT EXISTS v_top_scorers AS
      WITH scorer_aggregates AS (
        SELECT 
          pl.id AS player_id,
          pl.name,
          pl.nickname,
          pl.avatar_url,
          COUNT(CASE WHEN s.status = 'CLOSED' THEN 1 END) AS matches_played,
          COALESCE(SUM(CASE WHEN s.status = 'CLOSED' THEN pt.goals ELSE 0 END), 0) AS goals
        FROM players pl
        LEFT JOIN participations pt ON pt.player_id = pl.id
        LEFT JOIN sessions s ON s.id = pt.session_id
        WHERE pl.is_active = 1
        GROUP BY pl.id, pl.name, pl.nickname, pl.avatar_url
      )
      SELECT 
        ROW_NUMBER() OVER (ORDER BY goals DESC, matches_played ASC, name ASC) AS rank,
        player_id,
        name,
        nickname,
        avatar_url,
        matches_played,
        goals
      FROM scorer_aggregates
      WHERE goals > 0 OR matches_played > 0
      ORDER BY rank;
    ''');

    await db.execute('''
      CREATE VIEW IF NOT EXISTS v_top_assists AS
      WITH assist_aggregates AS (
        SELECT 
          pl.id AS player_id,
          pl.name,
          pl.nickname,
          pl.avatar_url,
          COUNT(CASE WHEN s.status = 'CLOSED' THEN 1 END) AS matches_played,
          COALESCE(SUM(CASE WHEN s.status = 'CLOSED' THEN pt.assists ELSE 0 END), 0) AS assists
        FROM players pl
        LEFT JOIN participations pt ON pt.player_id = pl.id
        LEFT JOIN sessions s ON s.id = pt.session_id
        WHERE pl.is_active = 1
        GROUP BY pl.id, pl.name, pl.nickname, pl.avatar_url
      )
      SELECT 
        ROW_NUMBER() OVER (ORDER BY assists DESC, matches_played ASC, name ASC) AS rank,
        player_id,
        name,
        nickname,
        avatar_url,
        matches_played,
        assists
      FROM assist_aggregates
      WHERE assists > 0 OR matches_played > 0
      ORDER BY rank;
    ''');

    await db.execute('''
      CREATE VIEW IF NOT EXISTS v_top_cards AS
      WITH card_aggregates AS (
        SELECT 
          pl.id AS player_id,
          pl.name,
          pl.nickname,
          pl.avatar_url,
          COUNT(CASE WHEN s.status = 'CLOSED' THEN 1 END) AS matches_played,
          COALESCE(SUM(CASE WHEN s.status = 'CLOSED' THEN pt.yellow_cards ELSE 0 END), 0) AS yellow_cards,
          COALESCE(SUM(CASE WHEN s.status = 'CLOSED' THEN pt.red_cards ELSE 0 END), 0) AS red_cards,
          COALESCE(SUM(CASE WHEN s.status = 'CLOSED' THEN (pt.yellow_cards + pt.red_cards) ELSE 0 END), 0) AS total_cards
        FROM players pl
        LEFT JOIN participations pt ON pt.player_id = pl.id
        LEFT JOIN sessions s ON s.id = pt.session_id
        WHERE pl.is_active = 1
        GROUP BY pl.id, pl.name, pl.nickname, pl.avatar_url
      )
      SELECT 
        ROW_NUMBER() OVER (ORDER BY (red_cards * 3 + yellow_cards) DESC, red_cards DESC, yellow_cards DESC, matches_played ASC, name ASC) AS rank,
        player_id,
        name,
        nickname,
        avatar_url,
        matches_played,
        yellow_cards,
        red_cards,
        total_cards
      FROM card_aggregates
      WHERE total_cards > 0 OR matches_played > 0
      ORDER BY rank;
    ''');

    await db.execute('''
      CREATE VIEW IF NOT EXISTS v_group_totals AS
      WITH session_counts AS (
        SELECT 
          COUNT(*) AS total_sessions,
          COUNT(CASE WHEN status = 'CLOSED' AND is_ranked = 1 THEN 1 END) AS ranked_sessions,
          COUNT(CASE WHEN status = 'CLOSED' AND is_ranked = 0 THEN 1 END) AS friendly_sessions,
          COALESCE(SUM(CASE WHEN status = 'CLOSED' THEN score_a + score_b ELSE 0 END), 0) AS total_score_goals,
          COALESCE(SUM(CASE WHEN status = 'CLOSED' THEN unassigned_goals_a + unassigned_goals_b ELSE 0 END), 0) AS explicit_unassigned_goals
        FROM sessions
      ),
      player_counts AS (
        SELECT 
          COUNT(*) AS total_players,
          COUNT(CASE WHEN is_active = 1 THEN 1 END) AS active_players
        FROM players
      ),
      part_counts AS (
        SELECT 
          COALESCE(SUM(pt.goals), 0) AS total_player_goals,
          COALESCE(SUM(pt.assists), 0) AS total_assists,
          COALESCE(SUM(pt.yellow_cards), 0) AS total_yellow_cards,
          COALESCE(SUM(pt.red_cards), 0) AS total_red_cards
        FROM participations pt
        JOIN sessions s ON s.id = pt.session_id
        WHERE s.status = 'CLOSED'
      )
      SELECT 
        sc.total_sessions,
        sc.ranked_sessions,
        sc.friendly_sessions,
        pc.total_players,
        pc.active_players,
        sc.total_score_goals AS total_goals,
        ROUND(CASE WHEN sc.total_sessions > 0 THEN CAST(sc.total_score_goals AS REAL) / sc.total_sessions ELSE 0.0 END, 2) AS avg_goals_per_session,
        pt.total_assists,
        pt.total_yellow_cards,
        pt.total_red_cards,
        pt.total_player_goals,
        MAX(0, sc.total_score_goals - pt.total_player_goals) AS unassigned_goals_difference
      FROM session_counts sc, player_counts pc, part_counts pt;
    ''');
  }

  Future<void> _seedDemoData(Database db) async {
    final batch = db.batch();

    // 14 players
    final players = [
      ['p1', 'Lucas', 'Lulu'],
      ['p2', 'Karim', 'Kaka'],
      ['p3', 'Sofiane', null],
      ['p4', 'Mehdi', 'Didi'],
      ['p5', 'Hugo', null],
      ['p6', 'Yassine', 'Yass'],
      ['p7', 'Théo', null],
      ['p8', 'Benjamin', 'Ben'],
      ['p9', 'Nicolas', 'Nico'],
      ['p10', 'Enzo', null],
      ['p11', 'Thomas', 'Tom'],
      ['p12', 'Antoine', 'Anto'],
      ['p13', 'Maxime', 'Max'],
      ['p14', 'Julien', 'Juju'],
    ];

    for (final p in players) {
      batch.rawInsert(
        'INSERT INTO players (id, name, nickname, is_active, created_at, updated_at) VALUES (?, ?, ?, 1, ?, ?)',
        [p[0], p[1], p[2], '2026-09-01 12:00:00', '2026-09-01 12:00:00'],
      );
    }

    // 14 closed ranked sessions
    final sessionsMeta = [
      ['s1', '2026-08-08 20:00:00', 5, 5, 'DRAW'],
      ['s2', '2026-08-15 20:00:00', 7, 6, 'A'],
      ['s3', '2026-08-22 20:00:00', 2, 3, 'B'],
      ['s4', '2026-08-29 20:00:00', 6, 4, 'A'],
      ['s5', '2026-09-02 20:00:00', 0, 0, 'DRAW'],
      ['s6', '2026-09-05 20:00:00', 4, 4, 'DRAW'],
      ['s7', '2026-09-07 20:00:00', 5, 2, 'A'],
      ['s8', '2026-09-08 20:00:00', 3, 4, 'B'],
      ['s9', '2026-09-09 20:30:00', 5, 3, 'A'],
      ['s10', '2026-09-12 20:00:00', 6, 2, 'A'],
      ['s11', '2026-09-15 20:00:00', 4, 1, 'A'],
      ['s12', '2026-09-18 20:00:00', 5, 3, 'A'],
      ['s13', '2026-09-20 20:00:00', 7, 4, 'A'],
      ['s14', '2026-09-23 20:00:00', 4, 2, 'A'],
    ];

    for (final s in sessionsMeta) {
      batch.rawInsert(
        'INSERT INTO sessions (id, played_at, status, is_ranked, score_a, score_b, result) VALUES (?, ?, ?, ?, ?, ?, ?)',
        [s[0], s[1], 'CLOSED', 1, s[2], s[3], s[4]],
      );
    }

    // Participations
    int partCount = 1;
    void addP(String sid, String pid, String team, int g, int a, [int y = 0, int r = 0]) {
      batch.rawInsert(
        'INSERT INTO participations (id, session_id, player_id, team, goals, assists, yellow_cards, red_cards) VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
        ['part_$partCount', sid, pid, team, g, a, y, r],
      );
      partCount++;
    }

    // Lucas (p1): 14 matches, 9 wins, 3 draws, 2 losses = 30 pts, 9 goals, 11 assists, 1 yellow, 0 red
    final lucasGoals = [1, 2, 0, 1, 0, 1, 1, 0, 2, 1, 0, 0, 0, 0];
    final lucasAssists = [1, 1, 0, 2, 0, 1, 1, 0, 1, 1, 1, 1, 1, 0];
    for (int i = 0; i < sessionsMeta.length; i++) {
      addP(sessionsMeta[i][0] as String, 'p1', 'A', lucasGoals[i], lucasAssists[i], i == 3 ? 1 : 0);
    }

    // Yassine (p6): 14 matches, 9 wins, 3 draws, 2 losses = 30 pts
    for (int i = 0; i < sessionsMeta.length; i++) {
      addP(sessionsMeta[i][0] as String, 'p6', 'A', i.isEven ? 1 : 0, i % 3 == 0 ? 1 : 0);
    }

    // Mehdi (p4): 12 matches, 9 wins, 2 draws, 1 loss = 29 pts
    for (int i = 0; i < 12; i++) {
      final team = sessionsMeta[i][0] == 's8' ? 'B' : 'A';
      addP(sessionsMeta[i][0] as String, 'p4', team, i.isOdd ? 1 : 0, 0);
    }

    // Karim (p2): 8 matches, 5 wins, 3 draws = 18 pts, 2 yellows, 1 red
    for (int i = 0; i < 8; i++) {
      final sid = sessionsMeta[i][0] as String;
      final team = (sid == 's3' || sid == 's8') ? 'B' : 'A';
      addP(sid, 'p2', team, i.isEven ? 1 : 0, 1, (i == 1 || i == 5) ? 1 : 0, i == 5 ? 1 : 0);
    }

    // Sofiane (p3): 10 matches, 1 yellow
    for (int i = 0; i < 10; i++) {
      final sid = sessionsMeta[i][0] as String;
      final team = i < 7 ? 'A' : 'B';
      addP(sid, 'p3', team, 0, i % 3 == 0 ? 1 : 0, i == 2 ? 1 : 0);
    }

    // Hugo (p5): 9 matches
    for (int i = 0; i < 9; i++) {
      final sid = sessionsMeta[i][0] as String;
      final team = (i == 1 || i == 3 || i == 6 || i == 8) ? 'A' : 'B';
      addP(sid, 'p5', team, i == 1 ? 1 : 0, 0);
    }

    // Benjamin (p8): 8 matches, 1 yellow
    for (int i = 0; i < 8; i++) {
      final sid = sessionsMeta[i][0] as String;
      addP(sid, 'p8', 'B', i == 2 ? 1 : 0, 0, i == 4 ? 1 : 0);
    }

    // Théo (p7): 7 matches
    for (int i = 0; i < 7; i++) {
      final sid = sessionsMeta[i][0] as String;
      addP(sid, 'p7', 'B', 0, 0);
    }

    // Nicolas (p9): 6 matches (< 50% threshold)
    for (int i = 8; i < 14; i++) {
      final sid = sessionsMeta[i][0] as String;
      addP(sid, 'p9', 'A', 1, 0);
    }

    // Enzo (p10): 5 matches (< 50% threshold), 1 red
    for (int i = 9; i < 14; i++) {
      final sid = sessionsMeta[i][0] as String;
      addP(sid, 'p10', 'A', 1, 0, 0, i == 10 ? 1 : 0);
    }

    // Thomas (p11): 4 matches (< 50% threshold)
    for (int i = 10; i < 14; i++) {
      final sid = sessionsMeta[i][0] as String;
      addP(sid, 'p11', 'A', 0, 0);
    }

    // Antoine (p12): 3 matches (< 50% threshold)
    for (int i = 11; i < 14; i++) {
      final sid = sessionsMeta[i][0] as String;
      addP(sid, 'p12', 'A', 0, 0);
    }

    // Maxime (p13): 2 matches (< 50% threshold)
    for (int i = 12; i < 14; i++) {
      final sid = sessionsMeta[i][0] as String;
      addP(sid, 'p13', 'A', 0, 0);
    }

    // Julien (p14): 1 match (< 50% threshold)
    addP('s14', 'p14', 'B', 0, 0);

    await batch.commit(noResult: true);
  }
}
