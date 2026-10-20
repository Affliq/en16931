# frozen_string_literal: true

module EN16931
  # Payment instructions (BG-16): SEPA credit transfer (code 58) by default.
  # `terms` is the payment terms text (BT-20); `reference` the remittance
  # information the buyer should quote (BT-83).
  Payment = Data.define(:iban, :bic, :holder, :means_code, :reference, :terms) do
    def initialize(iban: nil, bic: nil, holder: nil, means_code: nil, reference: nil, terms: nil)
      super(iban: iban&.delete(" "), bic: bic&.delete(" "), holder:, means_code: means_code || (iban ? "58" : "1"), reference:, terms:)
    end
  end
end
