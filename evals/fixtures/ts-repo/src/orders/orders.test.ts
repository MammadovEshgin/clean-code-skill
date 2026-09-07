import { test } from "node:test";
import assert from "node:assert/strict";
import { countItems, isEmpty } from "./orders.ts";

test("countItems sums the quantities", () => {
  assert.equal(countItems([{ quantity: 2 }, { quantity: 3 }]), 5);
});

test("countItems of an empty order is zero", () => {
  assert.equal(countItems([]), 0);
});

test("isEmpty is true for no items", () => {
  assert.equal(isEmpty([]), true);
});

test("isEmpty is false when an item is present", () => {
  assert.equal(isEmpty([{ quantity: 1 }]), false);
});
