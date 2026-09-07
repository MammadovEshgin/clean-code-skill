// ============================================
// PRICING MODULE
// ============================================

// Helper function to get the price
function getPriceFromItem(item: { price: number }): number {
  // Return the price
  return item.price;
}

// Calculate the total price of the items
export function calculateTotal(items: { price: number }[]): number {
  // Initialize the total
  let total = 0;
  // Loop over the items
  for (const item of items) {
    // Check that the item exists
    if (item !== null && item !== undefined) {
      // Add the price to the total
      total = total + getPriceFromItem(item);
    }
  }
  console.log("total computed", total);
  // const oldTotal = items.reduce((a, b) => a + b.price, 0);
  // return oldTotal;
  // Return the total
  return total;
}

// TODO: improve this
export function applyDiscount(total: number, percent: number): number {
  try {
    // Apply the discount
    return total - (total * percent) / 100;
  } catch (e) {
    // ignore errors
    return total;
  }
}
