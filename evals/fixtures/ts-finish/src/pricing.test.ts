import { test } from "node:test";
import assert from "node:assert/strict";
import { calculateTotal, applyDiscount } from "./pricing.ts";

test("calculateTotal sums the prices", () => {
  assert.equal(calculateTotal([{ price: 10 }, { price: 5 }]), 15);
});

test("calculateTotal of an empty cart is zero", () => {
  assert.equal(calculateTotal([]), 0);
});

test("applyDiscount takes the percentage off", () => {
  assert.equal(applyDiscount(100, 10), 90);
});

test("applyDiscount of zero percent leaves the total", () => {
  assert.equal(applyDiscount(42, 0), 42);
});
