import { test } from "node:test";
import assert from "node:assert/strict";
import { add, format } from "./money.ts";

test("add sums amounts in the same currency", () => {
  assert.deepEqual(add({ cents: 150, currency: "EUR" }, { cents: 275, currency: "EUR" }), { cents: 425, currency: "EUR" });
});

test("add rejects mixed currencies", () => {
  assert.throws(() => add({ cents: 1, currency: "EUR" }, { cents: 1, currency: "USD" }), /cannot add EUR to USD/);
});

test("format writes cents as a two-digit fraction", () => {
  assert.equal(format({ cents: 1005, currency: "EUR" }), "10.05 EUR");
});

test("format keeps the sign on negative amounts", () => {
  assert.equal(format({ cents: -150, currency: "EUR" }), "-1.50 EUR");
});
