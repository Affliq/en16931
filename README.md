# en16931

<p align="center"><sub>SPONSORED BY</sub></p>
<p align="center">
  <a href="https://www.company-mood.com"><picture><source media="(prefers-color-scheme: dark)" srcset=".github/sponsors/companymood-dark.svg"><img src=".github/sponsors/companymood.svg" alt="CompanyMood" height="40"></picture></a>
  &nbsp;&nbsp;&nbsp;&nbsp;
  <a href="https://myron.app"><picture><source media="(prefers-color-scheme: dark)" srcset=".github/sponsors/myron-dark.svg"><img src=".github/sponsors/myron.svg" alt="Myron" height="30"></picture></a>
  &nbsp;&nbsp;&nbsp;&nbsp;
  <a href="https://www.affliq.com"><picture><source media="(prefers-color-scheme: dark)" srcset=".github/sponsors/affliq-dark.svg"><img src=".github/sponsors/affliq.svg" alt="Affliq" height="42"></picture></a>
</p>

EN 16931 e-invoices for Ruby, in pure Ruby.

- A small invoice model: parties, lines, a VAT treatment, payment details.
- **XRechnung** XML (UN/CEFACT CII, the German CIUS of EN 16931) through [zugpferd](https://github.com/alexzeitler/zugpferd).
- **ZUGFeRD / Factur-X hybrid PDF/A-3b** with the XML embedded, built on [Prawn](https://prawnpdf.org) without Ghostscript, Java or hexapdf.
- A **letter layout with branding**: logo, accent colour, own typeface, opening and closing lines, and the GiroCode (EPC QR code) next to the bank details.
- **German VAT presets**: Regelbesteuerung, ermäßigter Satz, Kleinunternehmer (§ 19 UStG), Reverse Charge (§ 13b UStG), nicht im Inland steuerbar, innergemeinschaftliche Lieferung, Ausfuhr.
- Wrappers for the official validators, [KoSIT](https://github.com/itplr-kosit/validator) and [veraPDF](https://verapdf.org), so CI proves every invoice shape you ship.

Every fixture in `test/fixtures/invoices.rb` passes both validators; see `rake validate`.

## Install

```ruby
gem "en16931"
```

Ruby 3.2 to 4.0 (CI runs every one). No system dependencies at run time. The validators need Java 11+ (KoSIT) and the `verapdf` command or Docker (veraPDF); they are for CI, not for production.

## Usage

```ruby
require "en16931"

seller = EN16931::Party.new(
  name: "Lena Beispiel", street: "Musterstraße 12", postal_code: "10115", city: "Berlin", country: "DE",
  vat_id: "DE123456789", tax_number: "30/123/45678",
  email: "lena@example.com", phone: "+49 30 1234567", contact_name: "Lena Beispiel"
)
buyer = EN16931::Party.new(
  name: "GlowCo Cosmetics GmbH", street: "Industriestraße 5", postal_code: "20457", city: "Hamburg", country: "DE",
  vat_id: "DE987654321", email: "invoices@glowco.example"
)

invoice = EN16931::Invoice.new(
  number: "2026-0001", issue_date: Date.new(2026, 10, 20), due_date: Date.new(2026, 11, 3),
  seller: seller, buyer: buyer, buyer_reference: "PO-4711",
  references: { "Kostenstelle" => "4711" },     # printed in the header, an XML note
  tax: EN16931::DE.standard,
  lines: [EN16931::Line.new(description: "Produktvideo TikTok, 60 Sekunden", unit_price: BigDecimal("1500.00"))],
  payment: EN16931::Payment.new(iban: "DE89 3704 0044 0532 0130 00", bic: "COBADEFFXXX", holder: "Lena Beispiel",
                                terms: "Zahlbar innerhalb von 14 Tagen ohne Abzug.")
)

xml = EN16931::XML.cii(invoice)                 # XRechnung 3.0 (CII)
pdf = EN16931::PDF.render(invoice)              # ZUGFeRD hybrid PDF/A-3b, profile XRECHNUNG
File.binwrite("2026-0001.pdf", pdf)
```

Amounts, quantities and rates are kept as `BigDecimal`. They accept a `BigDecimal`, an `Integer` or a decimal `String` such as `"1500.00"`; a `Float` raises an `ArgumentError`, because it has already lost the exact value.

### Tax cases

| Preset | Category | Use |
|---|---|---|
| `EN16931::DE.standard` | S 19 % | Regelbesteuerung |
| `EN16931::DE.reduced` | S 7 % | ermäßigter Satz |
| `EN16931::DE.small_business` | E | Kleinunternehmer nach § 19 UStG; the note is printed and carried in BT-120 |
| `EN16931::DE.reverse_charge` | AE | business customer in another EU state; both VAT ids required |
| `EN16931::DE.not_taxable_abroad` | O | service to a business outside the EU; no VAT ids on the invoice, the seller is identified by tax number |
| `EN16931::DE.intra_community_supply` | K | goods to an EU business |
| `EN16931::DE.export_supply` | G | goods exported outside the EU |

A line or a document-level allowance/charge can carry its own `tax:`; otherwise the invoice's applies. `EN16931::Tax` builds any other treatment.

### Branding

The reference layout is a letter: letterhead, return-address line and recipient in the window position, title, details, lines, totals, payment block, footer with the tax ids. A `Branding` dresses it:

```ruby
branding = EN16931::Branding.new(
  logo: "logo.png",                      # PNG or JPEG (RGB; alpha is fine); a path, the bytes or an IO
  logo_position: :left,                  # or :right; the seller's name takes the other side
  logo_height: 40,                       # points; width follows, capped by logo_max_width (180)
  accent: "FF5A1F",                      # title and rules
  font: { normal: "Inter-Regular.ttf", bold: "Inter-Bold.ttf" },   # TrueType, embedded; DejaVu Sans otherwise
  intro: "vielen Dank für den Auftrag. Für die vereinbarte Leistung berechne ich wie folgt:",
  closing: "Vielen Dank für die gute Zusammenarbeit.\n\nLena Beispiel",
  giro_code: true                        # default: EPC QR code for euro invoices with an IBAN and an amount due
)
pdf = EN16931::PDF.render(invoice, branding:, locale: :de)
```

`locale:` sets the labels, number and date formats and the buyer's country name of the layout: `:de`, `:en`, `:cs`, `:da`, `:es`, `:et`, `:fi`, `:fr`, `:it`, `:lv`, `:nl`, `:pl`, `:pt`, `:ro`, `:ru`, `:sv`, `:tr` or `:zh` (a string works too; anything else falls back to German). DejaVu Sans covers every one of them but Chinese: for `:zh` pass a TrueType font with CJK glyphs as the branding font. Glyphs a branding font lacks, such as `€` in a subset, are taken from DejaVu Sans.

`Branding.new` rejects what would break PDF/A at construction time: CMYK JPEGs, interlaced PNGs, unknown image data. The GiroCode is drawn as vectors, so it adds no raster image; it carries the holder, IBAN, BIC, the amount due and the payment reference (or the invoice title) and is left out when the invoice is not in euro, has no IBAN or nothing is due.

### Your own layout

Draw the invoice with Prawn as you like, using embedded TrueType fonts (PDF/A forbids the unembedded base-14 fonts), then attach the XML:

```ruby
doc = Prawn::Document.new
doc.font_families.update("Inter" => { normal: "fonts/Inter-Regular.ttf", bold: "fonts/Inter-Bold.ttf" })
doc.font("Inter")
# ... your layout ...
EN16931::PDF::A3.attach(doc, EN16931::XML.cii(invoice), profile: :xrechnung, title: "Rechnung 2026-0001", author: seller.name)
pdf = doc.render
```

`profile:` is `:xrechnung` (file `xrechnung.xml`, conformance `XRECHNUNG`), `:en16931`, `:extended` or `:basic` (file `factur-x.xml`).

### Document types, periods, corrections

```ruby
EN16931::Invoice.new(type: :corrected, preceding: { number: "2026-0001", issue_date: Date.new(2026, 10, 20) }, ...)
EN16931::Invoice.new(type: :credit_note, ...)
EN16931::Invoice.new(type: :self_billed, ...)                     # Gutschrift im Sinne von § 14 Abs. 2 UStG
EN16931::Invoice.new(period: Date.new(2026, 10, 1)..Date.new(2026, 10, 31), ...)   # BG-14, e.g. a retainer month
EN16931::Invoice.new(prepaid: BigDecimal("200.00"), allowances: [EN16931::AllowanceCharge.new(amount: BigDecimal("100.00"), reason: "Treuerabatt", reason_code: "95")], ...)
```

### Validation

```ruby
kosit = EN16931::Validation::KoSIT.new.install!   # downloads the validator and the XRechnung configuration into tmp/kosit
report = kosit.validate(xml)
report.valid?      # => true
report.errors      # => [] (Message#code, #text)

vera = EN16931::Validation::VeraPDF.new            # `verapdf` command or the ghcr.io/verapdf/cli image
vera.validate(pdf).valid?
```

`rake validate` runs both over every fixture and prints the matrix; `rake examples` writes the fixtures to `examples/` as XML and PDF.

## What the fixtures cover

Standard 19 %, mixed rates with a discount, Kleinunternehmer, reverse charge to an EU agency, a service to a US company in USD, a retainer with an invoicing period, hours with a prepayment and a charge, a corrected invoice, a credit note, a self-billed payout statement.

## Legal notes

The presets reproduce the customary German invoice notes. Which treatment applies to a transaction, and whether an e-invoice is required at all (since 2025 every German business must be able to receive one; issuing becomes mandatory in stages until 2028, Kleinunternehmer are exempt from issuing), is a question for a tax adviser. The library validates form, not facts.

## Releasing

Bump `lib/en16931/version.rb`, move the changelog entries under the new version, commit, then tag and push:

```
git tag v0.2.0 && git push origin v0.2.0
```

`.github/workflows/release.yml` runs the tests and both validators again and publishes through [Trusted Publishing](https://guides.rubygems.org/trusted-publishing/); no API key is stored anywhere.

## Licences

MIT. Bundled: DejaVu Sans (Bitstream Vera licence, `fonts/LICENSE-DejaVu.txt`), the country names from the [Unicode CLDR](https://cldr.unicode.org) (Unicode licence, `data/LICENSE-CLDR.txt`) and the sRGB profile from [Compact ICC Profiles](https://github.com/saucecontrol/Compact-ICC-Profiles) (CC0).
