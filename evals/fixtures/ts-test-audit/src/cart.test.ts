import { test } from "node:test";
import assert from "node:assert/strict";
import { cartTotal, applyCoupon, type Item } from "./cart.ts";

test("cartTotal sums price times quantity", () => {
  const items: Item[] = [
    { price: 10, qty: 2 },
    { price: 5, qty: 1 },
  ];
  const expected = items.reduce((sum, i) => sum + i.price * i.qty, 0);
  assert.equal(cartTotal(items), expected);
});

test("cartTotal calls the reducer once per item", () => {
  const items: Item[] = [{ price: 1, qty: 1 }, { price: 2, qty: 1 }];
  let calls = 0;
  const spy = items.map((i) => ({ ...i, get price() { calls += 1; return i.price; } }));
  cartTotal(spy);
  assert.equal(calls, 2);
});

test("the test framework works", () => {
  assert.ok(true);
});

test("cartTotal of an empty cart is zero", () => {
  assert.equal(cartTotal([]), 0);
});

test("applyCoupon returns a number", () => {
  assert.equal(typeof applyCoupon(100, "HALF"), "number");
});
