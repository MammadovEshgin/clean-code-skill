import { test } from "node:test";
import assert from "node:assert/strict";
import { findUserByName, type Db, type User } from "./users.ts";

function fakeDb(rows: User[]): Db {
  return {
    async query() {
      return rows;
    },
  };
}

test("findUserByName returns the matching user", async () => {
  const user = await findUserByName(fakeDb([{ id: 1, name: "ada" }]), "ada");
  assert.deepEqual(user, { id: 1, name: "ada" });
});

test("findUserByName returns null when nobody matches", async () => {
  assert.equal(await findUserByName(fakeDb([]), "nobody"), null);
});
