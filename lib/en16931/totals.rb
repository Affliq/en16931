# frozen_string_literal: true

module EN16931
  # Document totals (BG-22) and the VAT breakdown (BG-23), computed the way
  # EN 16931 checks them: line nets summed, VAT rounded per category.
  class Totals
    Subtotal = Data.define(:tax, :taxable, :amount)

    attr_reader :line_total, :allowance_total, :charge_total, :net, :vat, :gross, :prepaid, :payable, :subtotals

    def self.compute(invoice) = new(invoice)

    def initialize(invoice)
      @line_total = invoice.lines.sum(&:net)
      @allowance_total = invoice.allowances.sum(&:amount)
      @charge_total = invoice.charges.sum(&:amount)
      @net = @line_total - @allowance_total + @charge_total
      @subtotals = breakdown(invoice)
      @vat = @subtotals.sum(&:amount)
      @gross = @net + @vat
      @prepaid = invoice.prepaid
      @payable = @gross - @prepaid
    end

    private

    # One subtotal per distinct tax treatment; amount = taxable × rate, rounded.
    # A negative base at 0 % gives BigDecimal -0, which the XML would print as
    # "-0.00" against a total of "0.00" (BR-CO-14); zero is zero.
    def breakdown(invoice)
      bases = Hash.new(BigDecimal("0"))
      invoice.lines.each { |line| bases[invoice.tax_for(line)] += line.net }
      invoice.allowances.each { |a| bases[a.tax || invoice.tax] -= a.amount }
      invoice.charges.each { |c| bases[c.tax || invoice.tax] += c.amount }
      bases.map do |tax, taxable|
        amount = (taxable * tax.rate / 100).round(2)
        Subtotal.new(tax: tax, taxable: taxable, amount: amount.zero? ? BigDecimal("0") : amount)
      end
    end
  end
end
