export type Item = { price: number; qty: number };

export function cartTotal(items: Item[]): number {
  let total = 0;
  for (const item of items) {
    total += item.price * item.qty;
  }
  return total;
}

// Known codes: HALF takes 50% off, TEN takes 10 off (never below zero). Unknown codes change nothing.
export function applyCoupon(total: number, code: string): number {
  if (code === "HALF") {
    return total * 0.5;
  }
  if (code === "TEN") {
    return Math.max(0, total - 10);
  }
  return total;
}
