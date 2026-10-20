## [Unreleased]

## [0.1.0] - 2026-10-20

- Invoice model with parties, lines, allowances and charges, payment details, periods and corrections.
- XRechnung 3.0 (CII) and plain EN 16931 XML through zugpferd, with seller tax number, BIC, account name, invoicing period and preceding invoice added.
- ZUGFeRD / Factur-X hybrid PDF/A-3b on Prawn in pure Ruby: XMP with the Factur-X extension schema, sRGB output intent, associated file.
- Reference invoice layout in German and English: a letter with return-address line and recipient in the DIN 5008 window position.
- Branding for the reference layout: logo (PNG/JPEG with alpha; CMYK and interlaced refused), position, accent colour, own TrueType font, intro and closing texts.
- GiroCode (EPC QR code, version 002) next to the bank details, drawn as vectors; on by default for euro invoices with an IBAN and an amount due.
- German VAT presets: standard, reduced, Kleinunternehmer, reverse charge, not taxable abroad, intra-community supply, export.
- KoSIT and veraPDF wrappers, `rake validate`, a fixture matrix of ten invoice shapes that pass both.
