# frozen_string_literal: true

module EN16931
  # German VAT presets. The texts are the customary invoice notes; whether a
  # case applies to a transaction is a question for the tax adviser, not for
  # this library.
  module DE
    STANDARD_RATE = 19
    REDUCED_RATE = 7

    module_function

    # Regelbesteuerung, 19 %.
    def standard = Tax.standard(STANDARD_RATE)

    # Ermäßigter Satz, 7 %.
    def reduced = Tax.standard(REDUCED_RATE)

    # Kleinunternehmer nach § 19 UStG: no VAT, mandatory note on the invoice.
    def small_business
      Tax.exempt(reason: "Gemäß § 19 UStG wird keine Umsatzsteuer berechnet.")
    end

    # Reverse charge for a business customer in another EU member state
    # (§ 13b UStG); both VAT identifiers go on the invoice.
    def reverse_charge
      Tax.reverse_charge(reason: "Steuerschuldnerschaft des Leistungsempfängers (Reverse Charge, § 13b UStG).")
    end

    # A service to a business outside the EU: the place of supply is abroad
    # (§ 3a Abs. 2 UStG), nothing is taxable in Germany.
    def not_taxable_abroad
      Tax.not_subject(reason: "Nicht im Inland steuerbar; der Leistungsort liegt beim Leistungsempfänger (§ 3a Abs. 2 UStG).")
    end

    # Goods to a business in another EU member state (§ 4 Nr. 1b UStG).
    def intra_community_supply
      Tax.intra_community(reason: "Steuerfreie innergemeinschaftliche Lieferung (§ 4 Nr. 1b UStG).")
    end

    # Goods exported outside the EU (§ 4 Nr. 1a UStG).
    def export_supply
      Tax.export(reason: "Steuerfreie Ausfuhrlieferung (§ 4 Nr. 1a UStG).")
    end
  end
end
