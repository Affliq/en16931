# frozen_string_literal: true

module EN16931
  # The invoice as the application knows it: who, to whom, what, under which
  # VAT treatment. Amounts are BigDecimal, money in the document currency.
  class Invoice
    TYPES = {
      invoice: "380",
      credit_note: "381",
      corrected: "384",
      self_billed: "389",
      partial: "326",
      prepayment: "386"
    }.freeze

    attr_reader :number, :issue_date, :due_date, :seller, :buyer, :lines, :tax, :currency, :buyer_reference,
                :type, :payment, :period, :notes, :delivery_date, :preceding, :allowances, :charges, :prepaid

    # @param preceding [Hash, nil] { number:, issue_date: } of the invoice a correction refers to (BG-3)
    # @param period [Range<Date>, nil] the invoicing period (BG-14), e.g. a retainer month
    def initialize(number:, issue_date:, seller:, buyer:, lines:, tax:, type: :invoice, due_date: nil, currency: "EUR",
                   buyer_reference: nil, payment: nil, period: nil, notes: [], delivery_date: nil, preceding: nil,
                   allowances: [], charges: [], prepaid: 0)
      raise ArgumentError, "unknown type #{type.inspect}" unless TYPES.key?(type)
      raise ArgumentError, "an invoice needs at least one line" if lines.empty?

      @number = number
      @issue_date = issue_date
      @due_date = due_date
      @seller = seller
      @buyer = buyer
      @lines = lines
      @tax = tax
      @type = type
      @currency = currency
      @buyer_reference = buyer_reference
      @payment = payment
      @period = period
      @notes = Array(notes)
      @delivery_date = delivery_date
      @preceding = preceding
      # The list decides the direction; the flag follows it.
      @allowances = allowances.map { |a| a.with(charge: false) }
      @charges = charges.map { |c| c.with(charge: true) }
      @prepaid = BigDecimal(prepaid.to_s)
    end

    def type_code = TYPES.fetch(type)
    def credit_note? = type == :credit_note
    def correction? = type == :corrected

    def totals = @totals ||= Totals.compute(self)

    # The tax of a line: its own, else the invoice's.
    def tax_for(line) = line.tax || tax

    # Every tax treatment that appears on the invoice, invoice-level first.
    def taxes = ([tax] + lines.map(&:tax) + (allowances + charges).map(&:tax)).compact.uniq
  end
end
