import { CapacitorSQLite, SQLiteConnection, SQLiteDBConnection } from '@capacitor-community/sqlite'
import { Capacitor } from '@capacitor/core'
import localforage from 'localforage'

const DB_NAME = 'statoo_db'
let sqliteConn: SQLiteConnection | null = null
let dbInstance: SQLiteDBConnection | null = null

export async function getDbConnection(): Promise<SQLiteDBConnection> {
  if (dbInstance) {
    try {
      const isOpen = await dbInstance.isDBOpen()
      if (isOpen.result) {
        return dbInstance
      }
    } catch {
      dbInstance = null
    }
  }

  if (!sqliteConn) {
    sqliteConn = new SQLiteConnection(CapacitorSQLite)
  }

  const platform = Capacitor.getPlatform ? Capacitor.getPlatform() : 'web'
  const isWeb = platform === 'web'

  if (isWeb) {
    // Expose localforage on window so jeep-sqlite can resolve it under Vite ESM
    if (typeof window !== 'undefined') {
      ;(window as any).localforage = localforage
    }

    const customElements = window.customElements
    if (customElements && !customElements.get('jeep-sqlite')) {
      const { defineCustomElements } = await import('jeep-sqlite/loader')
      await defineCustomElements(window)
    }

    let jeepEl = document.querySelector('jeep-sqlite')
    if (!jeepEl) {
      jeepEl = document.createElement('jeep-sqlite')
      jeepEl.setAttribute('wasmPath', '/')
      document.body.appendChild(jeepEl)
    }

    if (customElements) {
      await customElements.whenDefined('jeep-sqlite')
    }

    // Initialize web store
    await sqliteConn.initWebStore()
  }

  const isConn = (await sqliteConn.isConnection(DB_NAME, false)).result
  if (isConn) {
    dbInstance = await sqliteConn.retrieveConnection(DB_NAME, false)
  } else {
    dbInstance = await sqliteConn.createConnection(DB_NAME, false, 'no-encryption', 1, false)
  }

  await dbInstance.open()
  await dbInstance.execute('PRAGMA foreign_keys = ON;')

  return dbInstance
}

export async function saveWebStore(): Promise<void> {
  const platform = Capacitor.getPlatform ? Capacitor.getPlatform() : 'web'
  if (platform === 'web' && sqliteConn) {
    await sqliteConn.saveToStore(DB_NAME)
  }
}

export async function closeDbConnection(): Promise<void> {
  if (dbInstance && sqliteConn) {
    await saveWebStore()
    await sqliteConn.closeConnection(DB_NAME, false)
    dbInstance = null
  }
}
