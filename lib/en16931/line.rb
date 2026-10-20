# frozen_string_literal: true

module EN16931
  # One invoice line (BG-25). Quantity times unit price, rounded to cents,
  # is the line net (BT-131). The tax defaults to the invoice's tax.
  #
  # Common unit codes (UN/ECE Recommendation 20): C62 piece, HUR hour,
  # DAY day, MON month, LS lump sum, E48 service unit.
  Line = Data.define(:description, :quantity, :unit, :unit_price, :tax, :note, :sellers_id, :period) do
    def initialize(description:, unit_price:, quantity: 1, unit: "C62", tax: nil, note: nil, sellers_id: nil, period: nil)
      super(description:, quantity: BigDecimal(quantity.to_s), unit:, unit_price: BigDecimal(unit_price.to_s),
            tax:, note:, sellers_id:, period:)
    end

    def net = (quantity * unit_price).round(2)
  end

  # A document-level allowance (discount) or charge (BG-20 / BG-21).
  AllowanceCharge = Data.define(:amount, :reason, :charge, :reason_code, :tax) do
    def initialize(amount:, reason:, charge: false, reason_code: nil, tax: nil)
      super(amount: BigDecimal(amount.to_s), reason:, charge:, reason_code:, tax:)
    end

    def charge? = charge
    def signed_amount = charge? ? amount : -amount
  end
end
