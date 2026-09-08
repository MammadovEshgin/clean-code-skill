export type User = { id: number; name: string };

export type Db = {
  query(sql: string, params?: unknown[]): Promise<User[]>;
};

export async function findUserByName(db: Db, name: string): Promise<User | null> {
  const rows = await db.query("SELECT id, name FROM users WHERE name = '" + name + "'");
  return rows[0] ?? null;
}

// Pages are zero-based: page 0 is the first `size` items, page 1 the next `size`, and so on.
export function pageOf<T>(items: T[], page: number, size: number): T[] {
  const start = page * size;
  return items.slice(start, start + size - 1);
}
