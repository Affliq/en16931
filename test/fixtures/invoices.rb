# frozen_string_literal: true

# The fixture matrix: every tax case the library claims to handle, every
# document type, and the shapes that trip up validators (several rates, a
# discount, a period, a prepayment, a foreign currency). Each one must pass
# the KoSIT validator (XML) and veraPDF (PDF/A-3b); see `rake validate`.
module Fixtures
  SELLER = EN16931::Party.new(
    name: "Lena Beispiel", street: "Musterstraße 12", postal_code: "10115", city: "Berlin", country: "DE",
    vat_id: "DE123456789", tax_number: "30/123/45678", email: "lena@example.com", phone: "+49 30 1234567",
    contact_name: "Lena Beispiel"
  )
  SMALL_BUSINESS_SELLER = EN16931::Party.new(
    name: "Max Muster", street: "Gartenweg 3", postal_code: "66773", city: "Schwalbach", country: "DE",
    tax_number: "040/123/45678", email: "max@example.com", phone: "+49 6834 12345", contact_name: "Max Muster"
  )
  BUYER_DE = EN16931::Party.new(
    name: "GlowCo Cosmetics GmbH", street: "Industriestraße 5", postal_code: "20457", city: "Hamburg", country: "DE",
    vat_id: "DE987654321", email: "invoices@glowco.example"
  )
  BUYER_FR = EN16931::Party.new(
    name: "Agence Lumière SAS", street: "12 rue de la Paix", postal_code: "75002", city: "Paris", country: "FR",
    vat_id: "FR12345678901", email: "compta@lumiere.example"
  )
  BUYER_US = EN16931::Party.new(
    name: "Streamly Inc.", street: "1 Market St", postal_code: "94105", city: "San Francisco", country: "US",
    email: "ap@streamly.example"
  )
  PAYMENT = EN16931::Payment.new(iban: "DE89 3704 0044 0532 0130 00", bic: "COBADEFFXXX", holder: "Lena Beispiel",
                                 terms: "Zahlbar innerhalb von 14 Tagen ohne Abzug.")
  DATE = Date.new(2026, 10, 20)

  def self.base(**overrides)
    {
      number: "2026-0001", issue_date: DATE, due_date: DATE + 14, seller: SELLER, buyer: BUYER_DE,
      tax: EN16931::DE.standard, buyer_reference: "PO-4711", payment: PAYMENT, delivery_date: DATE,
      lines: [EN16931::Line.new(description: "Produktvideo TikTok, 60 Sekunden", unit_price: "1500.00")]
    }.merge(overrides)
  end

  def self.all
    {
      standard_19: EN16931::Invoice.new(**base),
      mixed_rates_discount: EN16931::Invoice.new(**base(
        number: "2026-0002",
        lines: [
          EN16931::Line.new(description: "Produktvideo", unit_price: "1200.00"),
          EN16931::Line.new(description: "Story-Serie, 3 Stück", quantity: 3, unit_price: "150.00"),
          EN16931::Line.new(description: "Gedrucktes Lookbook", quantity: 2, unit_price: "12.50", tax: EN16931::DE.reduced)
        ],
        allowances: [EN16931::AllowanceCharge.new(amount: "100.00", reason: "Treuerabatt", reason_code: "95")]
      )),
      small_business: EN16931::Invoice.new(**base(
        number: "2026-0003", seller: SMALL_BUSINESS_SELLER, tax: EN16931::DE.small_business,
        payment: EN16931::Payment.new(iban: "DE02120300000000202051", bic: "BYLADEM1001", holder: "Max Muster", terms: "Zahlbar sofort ohne Abzug."),
        lines: [EN16931::Line.new(description: "Unboxing-Video", unit_price: "400.00")]
      )),
      reverse_charge_eu: EN16931::Invoice.new(**base(
        number: "2026-0004", buyer: BUYER_FR.with(contact_name: "Claire Martin"), tax: EN16931::DE.reverse_charge,
        references: { "Centre de coûts" => "MKT-12" },
        lines: [EN16931::Line.new(description: "Content creation October 2026", unit_price: "800.00")]
      )),
      third_country_usd: EN16931::Invoice.new(**base(
        number: "2026-0005", buyer: BUYER_US, tax: EN16931::DE.not_taxable_abroad, currency: "USD",
        lines: [EN16931::Line.new(description: "Sponsored stream, 2 hours", quantity: 2, unit: "HUR", unit_price: "250.00")]
      )),
      retainer_period: EN16931::Invoice.new(**base(
        number: "2026-0006", period: Date.new(2026, 10, 1)..Date.new(2026, 10, 31), delivery_date: nil,
        lines: [EN16931::Line.new(description: "Monatliche Content-Pauschale", unit: "MON", unit_price: "800.00")]
      )),
      hourly_prepaid: EN16931::Invoice.new(**base(
        number: "2026-0007", prepaid: "200.00",
        lines: [EN16931::Line.new(description: "Beratung Social-Media-Strategie", quantity: "7.5", unit: "HUR", unit_price: "90.00")],
        charges: [EN16931::AllowanceCharge.new(amount: "25.00", reason: "Versand Requisiten")]
      )),
      corrected_invoice: EN16931::Invoice.new(**base(
        number: "2026-0008", type: :corrected, preceding: { number: "2026-0001", issue_date: DATE },
        notes: ["Korrektur der Rechnung 2026-0001: Menge berichtigt."],
        lines: [EN16931::Line.new(description: "Produktvideo TikTok, 60 Sekunden", unit_price: "1400.00")]
      )),
      credit_note: EN16931::Invoice.new(**base(
        number: "2026-G001", type: :credit_note, preceding: { number: "2026-0002", issue_date: DATE },
        lines: [EN16931::Line.new(description: "Gutschrift Story-Serie, nicht geliefert", unit_price: "150.00")]
      )),
      self_billed_payout: EN16931::Invoice.new(**base(
        number: "SB-2026-10", type: :self_billed, buyer: BUYER_FR, tax: EN16931::DE.reverse_charge, buyer_reference: "CREATOR-8812",
        period: Date.new(2026, 9, 1)..Date.new(2026, 9, 30), delivery_date: nil,
        lines: [EN16931::Line.new(description: "Platform revenue share September 2026", unit_price: "1234.56")]
      ))
    }
  end

  def self.each(&) = all.each(&)

  # A full dress: logo, accent, texts, GiroCode. The PNG has an alpha channel
  # on purpose, since transparency is the PDF/A trap a logo walks into.
  BRANDING = EN16931::Branding.new(
    logo: File.join(__dir__, "logo.png"), logo_position: :left, accent: "FF5A1F",
    intro: "vielen Dank für den Auftrag. Für die vereinbarte Leistung berechne ich wie folgt:",
    closing: "Vielen Dank für die gute Zusammenarbeit.\n\nLena Beispiel"
  )

  # Every PDF the validators see: each invoice plain, plus the branded
  # renders. Yields name, invoice and the options for PDF.render.
  def self.renders
    base = all.transform_values { |invoice| [invoice, {}] }
    base.merge(
      branded: [all[:standard_19], { branding: BRANDING }],
      branded_right_en: [all[:reverse_charge_eu], { branding: BRANDING.with(logo_position: :right, intro: nil, closing: "Thank you for working with me."), locale: :en }]
    )
  end
end
