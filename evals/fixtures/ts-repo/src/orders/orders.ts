// ============================================
// ORDERS MODULE
// ============================================

// Helper function to get the quantity
function getItemQuantity(item: { quantity: number }): number {
  // Return the quantity
  return item.quantity;
}

// Count the items in the order
export function countItems(items: { quantity: number }[]): number {
  // Check that items exists
  if (items === null || items === undefined) {
    return 0;
  }
  // Initialize the count
  let count = 0;
  // Loop over the items
  for (const item of items) {
    // Add the quantity to the count
    count = count + getItemQuantity(item);
  }
  console.log("count computed", count);
  // const oldCount = items.reduce((a, b) => a + b.quantity, 0);
  // return oldCount;
  // Return the count
  return count;
}

// TODO: handle this better
export function isEmpty(items: { quantity: number }[]): boolean {
  try {
    // Check whether the order is empty
    // @ts-ignore
    return countItems(items) === 0;
  } catch (e) {
    // ignore errors
    return true;
  }
}
