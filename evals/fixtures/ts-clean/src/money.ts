export type Money = { readonly cents: number; readonly currency: string };

export function add(a: Money, b: Money): Money {
  if (a.currency !== b.currency) {
    throw new Error(`cannot add ${a.currency} to ${b.currency}`);
  }
  return { cents: a.cents + b.cents, currency: a.currency };
}

export function format(money: Money): string {
  const sign = money.cents < 0 ? "-" : "";
  const magnitude = Math.abs(money.cents);
  const whole = Math.trunc(magnitude / 100);
  const fraction = (magnitude % 100).toString().padStart(2, "0");
  return `${sign}${whole}.${fraction} ${money.currency}`;
}
