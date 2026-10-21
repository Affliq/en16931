# frozen_string_literal: true

require "test_helper"
require "pdf/reader"

class LocalesTest < Minitest::Test
  Renderer = EN16931::PDF::Renderer

  def setup
    @invoice = Fixtures.all[:standard_19]
  end

  def test_every_locale_has_every_label_and_a_format
    keys = Renderer::LABELS[:de].keys
    Renderer::LABELS.each do |locale, labels|
      assert_equal keys, labels.keys, "#{locale} labels"
      assert_equal Renderer::UNIT_CODES, labels[:units].keys, "#{locale} units"
      assert Renderer::FORMATS.key?(locale), "#{locale} format"
    end
  end

  def test_unknown_or_string_locales_fall_back_without_errors
    assert_equal :de, Renderer.locale(:xx)
    assert_equal :de, Renderer.locale(nil)
    assert_equal :fr, Renderer.locale("fr")
    pdf = EN16931::PDF.render(@invoice, locale: :xx)
    assert_equal "Rechnung 2026-0001", ::PDF::Reader.new(StringIO.new(pdf)).info[:Title]
  end

  # Chinese needs a CJK font, which the gem does not bundle; see the README.
  def test_every_latin_and_cyrillic_locale_renders_its_labels_and_formats
    (Renderer::LABELS.keys - [:zh]).each do |locale|
      pdf = EN16931::PDF.render(@invoice, locale:)
      reader = ::PDF::Reader.new(StringIO.new(pdf))
      labels = Renderer::LABELS[locale]
      assert_equal "#{labels[:invoice]} 2026-0001", reader.info[:Title], locale
      text = reader.pages.first.text
      assert_includes text, labels[:payable], locale
      assert_includes text, @invoice.issue_date.strftime(Renderer::FORMATS[locale][2]), locale
    end
  end

  def test_number_format_follows_the_locale
    texts = %i[de en fr].to_h { |locale| [locale, ::PDF::Reader.new(StringIO.new(EN16931::PDF.render(@invoice, locale:))).pages.first.text] }
    assert_includes texts[:de], "1.785,00 €"
    assert_includes texts[:en], "1,785.00 €"
    assert_includes texts[:fr], "1 785,00 €"
  end

  def test_brand_font_falls_back_to_dejavu_for_missing_glyphs
    branding = EN16931::Branding.new(font: { normal: EN16931.font_path("DejaVuSans-Bold.ttf") })
    assert_equal [Renderer::FONT], Renderer.new(@invoice, branding:).document.fallback_fonts
    assert_empty Renderer.new(@invoice).document.fallback_fonts
  end
end
