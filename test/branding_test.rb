# frozen_string_literal: true

require "test_helper"

class BrandingTest < Minitest::Test
  LOGO = File.join(__dir__, "fixtures", "logo.png")

  def test_logo_from_path_bytes_or_io_is_the_same
    bytes = File.binread(LOGO)
    assert_equal bytes, EN16931::Branding.new(logo: LOGO).logo
    assert_equal bytes, EN16931::Branding.new(logo: bytes).logo
    assert_equal bytes, EN16931::Branding.new(logo: StringIO.new(bytes)).logo
    assert_nil EN16931::Branding.new.logo
  end

  def test_logo_size_keeps_the_aspect_ratio_and_caps_the_width
    assert_equal [120.0, 40.0], EN16931::Branding.new(logo: LOGO).logo_size
    assert_equal [90.0, 30.0], EN16931::Branding.new(logo: LOGO, logo_height: 40, logo_max_width: 90).logo_size
  end

  def test_rejects_what_pdf_a_cannot_take
    assert_raises(ArgumentError) { EN16931::Branding.new(accent: "orange") }
    assert_raises(ArgumentError) { EN16931::Branding.new(logo_position: :center) }
    assert_raises(Prawn::Errors::UnsupportedImageType) { EN16931::Branding.new(logo: StringIO.new("not an image")) }
    assert_raises(ArgumentError) { EN16931::Branding.new(font: { bold: "x.ttf" }) }
  end

  def test_font_takes_a_single_file_for_both_styles
    assert_equal({ normal: "a.ttf", bold: "a.ttf" }, EN16931::Branding.new(font: "a.ttf").font)
    assert_equal({ normal: "a.ttf", bold: "b.ttf" }, EN16931::Branding.new(font: { normal: "a.ttf", bold: "b.ttf" }).font)
  end

  def test_giro_code_payload_follows_the_epc_guideline
    payload = EN16931::PDF::GiroCode.payload(Fixtures.all[:standard_19], remittance: "Rechnung 2026-0001")
    assert_equal ["BCD", "002", "1", "SCT", "COBADEFFXXX", "Lena Beispiel", "DE89370400440532013000", "EUR1785.00", "", "", "Rechnung 2026-0001"],
                 payload.split("\n")
  end

  def test_giro_code_payload_needs_euro_iban_and_an_amount_due
    assert_nil EN16931::PDF::GiroCode.payload(Fixtures.all[:third_country_usd], remittance: "x")
    no_iban = EN16931::Invoice.new(**Fixtures.base(payment: EN16931::Payment.new(terms: "Bar")))
    assert_nil EN16931::PDF::GiroCode.payload(no_iban, remittance: "x")
    settled = EN16931::Invoice.new(**Fixtures.base(prepaid: "1785.00"))
    assert_nil EN16931::PDF::GiroCode.payload(settled, remittance: "x")
  end

  def test_giro_code_uses_the_payment_reference_and_truncates
    payment = EN16931::Payment.new(iban: "DE89370400440532013000", holder: "H" * 80, reference: "R" * 150)
    payload = EN16931::PDF::GiroCode.payload(EN16931::Invoice.new(**Fixtures.base(payment:)), remittance: "x")
    lines = payload.split("\n")
    assert_equal "", lines[4]
    assert_equal 70, lines[5].length
    assert_equal 140, lines[10].length
  end
end
