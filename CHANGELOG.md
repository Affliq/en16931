## [Unreleased]

## [0.2.2] - 2026-10-26

- A cancellation with negative quantities at 0 % VAT (small business, reverse charge, outside the scope) no longer writes a VAT amount of "-0.00" into the breakdown, which failed BR-CO-14 against the total of "0.00".
- The reference layout prints negative quantities and amounts with their minus sign; it dropped the sign while grouping the thousands, so a cancellation read like an invoice.

## [0.2.1] - 2026-10-22

- The buyer's country is named in the invoice language for every ISO country, from the Unicode CLDR (`data/countries.yml`, `rake countries`). Before, only nine countries had a name, in German.

## [0.2.0] - 2026-10-22

- **Breaking:** amounts, quantities and rates (`Line#unit_price`, `Line#quantity`, `AllowanceCharge#amount`, `Tax#rate`, `Invoice#prepaid`) refuse a `Float` with an `ArgumentError`. Pass a `BigDecimal`, an `Integer` or a decimal `String`.

## [0.1.3] - 2026-10-21

- The recipient block shows the buyer's contact person ("z. Hd.") and VAT identifier. Like the XML, it leaves the VAT identifier out for invoices outside the scope of VAT (category O).
- `Invoice#references` takes further references of the buyer, such as a cost centre or an order number. The layout prints them in the header below the buyer reference; the XML, which has no field for them, carries them as notes.

## [0.1.2] - 2026-10-21

- Long payment terms no longer run under the GiroCode; beside it the payment block is narrower.

## [0.1.1] - 2026-10-21

- The reference layout speaks 18 languages: German and English plus Czech, Danish, Spanish, Estonian, Finnish, French, Italian, Latvian, Dutch, Polish, Portuguese, Romanian, Russian, Swedish, Turkish and Chinese, each with its own number and date format.
- `PDF.render` no longer raises a `KeyError` for a locale the layout does not know; it falls back to German like the renderer does. Locales may be given as strings.
- Glyphs a branding font lacks are drawn with DejaVu Sans instead of the `.notdef` glyph, which PDF/A forbids.

## [0.1.0] - 2026-10-20

- Invoice model with parties, lines, allowances and charges, payment details, periods and corrections.
- XRechnung 3.0 (CII) and plain EN 16931 XML through zugpferd, with seller tax number, BIC, account name, invoicing period and preceding invoice added.
- ZUGFeRD / Factur-X hybrid PDF/A-3b on Prawn in pure Ruby: XMP with the Factur-X extension schema, sRGB output intent, associated file.
- Reference invoice layout in German and English: a letter with return-address line and recipient in the DIN 5008 window position.
- Branding for the reference layout: logo (PNG/JPEG with alpha; CMYK and interlaced refused), position, accent colour, own TrueType font, intro and closing texts.
- GiroCode (EPC QR code, version 002) next to the bank details, drawn as vectors; on by default for euro invoices with an IBAN and an amount due.
- German VAT presets: standard, reduced, Kleinunternehmer, reverse charge, not taxable abroad, intra-community supply, export.
- KoSIT and veraPDF wrappers, `rake validate`, a fixture matrix of ten invoice shapes that pass both.
