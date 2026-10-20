# frozen_string_literal: true

require "test_helper"

class TotalsTest < Minitest::Test
  def test_vat_is_rounded_per_category_and_allowances_reduce_the_base
    invoice = Fixtures.all[:mixed_rates_discount]
    t = invoice.totals
    assert_equal BigDecimal("1675.00"), t.line_total
    assert_equal BigDecimal("1575.00"), t.net
    by_rate = t.subtotals.to_h { |s| [s.tax.rate.to_i, s] }
    assert_equal BigDecimal("1550.00"), by_rate[19].taxable
    assert_equal BigDecimal("294.50"), by_rate[19].amount
    assert_equal BigDecimal("25.00"), by_rate[7].taxable
    assert_equal BigDecimal("1.75"), by_rate[7].amount
    assert_equal BigDecimal("1871.25"), t.gross
  end

  def test_exempt_categories_carry_no_vat
    t = Fixtures.all[:small_business].totals
    assert_equal BigDecimal("0"), t.vat
    assert_equal t.net, t.gross
    assert_equal "E", t.subtotals.first.tax.category
  end

  def test_prepaid_and_charges
    t = Fixtures.all[:hourly_prepaid].totals
    assert_equal BigDecimal("675.00"), t.line_total
    assert_equal BigDecimal("700.00"), t.net
    assert_equal BigDecimal("133.00"), t.vat
    assert_equal BigDecimal("633.00"), t.payable
  end

  def test_fractional_quantities_round_the_line_net
    line = EN16931::Line.new(description: "x", quantity: "1.333", unit_price: "9.99")
    assert_equal BigDecimal("13.32"), line.net
  end
end
