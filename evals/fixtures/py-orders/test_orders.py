import unittest

from orders import apply_discount, calculate_total


class OrdersTest(unittest.TestCase):
    def test_total_sums_prices(self):
        self.assertEqual(calculate_total([{"price": 10}, {"price": 5}]), 15)

    def test_total_of_empty_cart_is_zero(self):
        self.assertEqual(calculate_total([]), 0)

    def test_discount_takes_percentage_off(self):
        self.assertEqual(apply_discount(100, 10), 90)

    def test_zero_discount_leaves_total(self):
        self.assertEqual(apply_discount(42, 0), 42)


if __name__ == "__main__":
    unittest.main()
