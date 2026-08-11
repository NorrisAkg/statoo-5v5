import { ref } from 'vue'
import { SQLiteDBConnection } from '@capacitor-community/sqlite'
import { getDbConnection } from '~/lib/db/connection'
import { runMigrations } from '~/lib/db/migrations'

const isInitialized = ref(false)
const initError = ref<string | null>(null)
let db: SQLiteDBConnection | null = null

export function useDb() {
  async function initDb(): Promise<SQLiteDBConnection> {
    if (isInitialized.value && db) {
      return db
    }

    try {
      db = await getDbConnection()
      await runMigrations(db)
      isInitialized.value = true
      initError.value = null
      return db
    } catch (err: any) {
      console.error('Failed to initialize database:', err)
      initError.value = err.message || 'Database initialization error'
      throw err
    }
  }

  return {
    isInitialized,
    initError,
    initDb,
    getDb: () => db,
  }
}
