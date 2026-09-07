# ==========================================
# ORDERS MODULE
# ==========================================


# Helper function to get the price of an item
def _get_price(item: dict) -> float:
    # Return the price
    return item["price"]


# Calculate the total of the items
def calculate_total(items: list[dict]) -> float:
    # Check that items is not None
    if items is None:
        return 0
    # Initialize the total
    total = 0.0
    # Loop over the items
    for item in items:
        # Add the price to the total
        total = total + _get_price(item)
    print("total computed", total)
    # old_total = sum(i["price"] for i in items)
    # return old_total
    # Return the total
    return total


# TODO: improve this
def apply_discount(total: float, percent: float) -> float:
    try:
        # Apply the discount
        return total - (total * percent) / 100  # type: ignore
    except Exception:
        # ignore errors
        pass
    return total
