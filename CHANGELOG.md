## [Unreleased]

## [0.1.0] - 2026-10-20

- Invoice model with parties, lines, allowances and charges, payment details, periods and corrections.
- XRechnung 3.0 (CII) and plain EN 16931 XML through zugpferd, with seller tax number, BIC, account name, invoicing period and preceding invoice added.
- ZUGFeRD / Factur-X hybrid PDF/A-3b on Prawn in pure Ruby: XMP with the Factur-X extension schema, sRGB output intent, associated file.
- Reference invoice layout in German and English.
- German VAT presets: standard, reduced, Kleinunternehmer, reverse charge, not taxable abroad, intra-community supply, export.
- KoSIT and veraPDF wrappers, `rake validate`, a fixture matrix of ten invoice shapes that pass both.
