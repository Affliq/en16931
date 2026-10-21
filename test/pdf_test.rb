# frozen_string_literal: true

require "test_helper"
require "pdf/reader"

class PDFTest < Minitest::Test
  def setup
    @invoice = Fixtures.all[:standard_19]
    @pdf = EN16931::PDF.render(@invoice, created_at: Time.utc(2026, 10, 20, 12))
  end

  def test_pdf_a3_structure
    assert @pdf.start_with?("%PDF-1.7")
    assert_includes @pdf, "/AFRelationship /Alternative"
    assert_includes @pdf, "/Type /EmbeddedFile"
    assert_includes @pdf, "/Subtype /text#2Fxml"
    assert_includes @pdf, "/EmbeddedFiles"
    assert_includes @pdf, "/OutputIntents"
    assert_includes @pdf, "/S /GTS_PDFA1"
    assert_includes @pdf, "<pdfaid:part>3</pdfaid:part>"
    assert_includes @pdf, "<fx:ConformanceLevel>XRECHNUNG</fx:ConformanceLevel>"
    assert_includes @pdf, "<fx:DocumentFileName>xrechnung.xml</fx:DocumentFileName>"
    assert_match(%r{/ID \[\(.+\) \(.+\)\]}, @pdf)
  end

  def test_only_embedded_truetype_fonts_are_used
    refute_includes @pdf, "/BaseFont /Helvetica"
    reader = ::PDF::Reader.new(StringIO.new(@pdf))
    fonts = reader.objects.values.select { |o| o.is_a?(Hash) && o[:Type] == :Font }
    refute_empty fonts
    assert fonts.all? { |f| %i[TrueType Type0].include?(f[:Subtype]) }, fonts.map { |f| f[:Subtype] }.inspect
  end

  def test_embedded_xml_round_trips
    reader = ::PDF::Reader.new(StringIO.new(@pdf))
    embedded = reader.objects.values.find { |o| o.is_a?(::PDF::Reader::Stream) && o.hash[:Type] == :EmbeddedFile }
    xml = embedded.unfiltered_data.force_encoding("UTF-8")
    assert_equal EN16931::XML.cii(@invoice), xml
    filespec = reader.objects.values.find { |o| o.is_a?(Hash) && o[:Type] == :Filespec }
    assert_equal "xrechnung.xml", filespec[:F]
    assert_equal :Alternative, filespec[:AFRelationship]
    assert_equal "2026-0001", Nokogiri::XML(xml).at_xpath("//rsm:ExchangedDocument/ram:ID", EN16931::XML::NS).text
  end

  def test_info_dictionary_mirrors_xmp
    reader = ::PDF::Reader.new(StringIO.new(@pdf))
    info = reader.info
    assert_equal "Rechnung 2026-0001", info[:Title]
    assert_equal "Lena Beispiel", info[:Author]
    assert_includes @pdf, "<dc:title><rdf:Alt><rdf:li xml:lang=\"x-default\">Rechnung 2026-0001</rdf:li>"
    assert_includes @pdf, "<xmp:CreateDate>2026-10-20T12:00:00Z</xmp:CreateDate>"
  end

  def test_every_fixture_renders
    Fixtures.renders.each do |name, (invoice, options)|
      pdf = EN16931::PDF.render(invoice, **options)
      assert pdf.bytesize > 10_000, "#{name} rendered nothing"
      assert_equal 1, ::PDF::Reader.new(StringIO.new(pdf)).page_count, "#{name} should fit on one page"
    end
  end

  def test_branded_render_carries_logo_texts_and_giro_code
    pdf = EN16931::PDF.render(@invoice, branding: Fixtures::BRANDING)
    reader = ::PDF::Reader.new(StringIO.new(pdf))
    images = reader.objects.values.select { |o| o.is_a?(::PDF::Reader::Stream) && o.hash[:Subtype] == :Image }
    assert_equal 2, images.size, "logo image and its alpha mask"
    assert images.any? { |i| i.hash[:SMask] }, "the PNG alpha channel becomes a soft mask"
    assert(images.all? { |i| %i[DeviceRGB DeviceGray].include?(i.hash[:ColorSpace]) })
    text = reader.pages.first.text
    assert_includes text, "vielen Dank für den Auftrag"
    assert_includes text, "Vielen Dank für die gute Zusammenarbeit."
    assert_includes text, "GiroCode"
    assert_includes text, "Lena Beispiel · Musterstraße 12 · 10115 Berlin"
  end

  def test_plain_render_has_giro_code_but_no_image
    reader = ::PDF::Reader.new(StringIO.new(@pdf))
    refute(reader.objects.values.any? { |o| o.is_a?(::PDF::Reader::Stream) && o.hash[:Subtype] == :Image })
    assert_includes reader.pages.first.text, "GiroCode"
  end

  def test_giro_code_is_left_out_when_the_invoice_cannot_carry_one
    usd = Fixtures.all[:third_country_usd]
    refute_includes ::PDF::Reader.new(StringIO.new(EN16931::PDF.render(usd))).pages.first.text, "Scan to pay"
    off = EN16931::PDF.render(@invoice, branding: EN16931::Branding.new(giro_code: false))
    refute_includes ::PDF::Reader.new(StringIO.new(off)).pages.first.text, "GiroCode"
  end

  def test_branded_render_with_own_font_embeds_it
    branding = EN16931::Branding.new(font: { normal: EN16931.font_path("DejaVuSans-Bold.ttf") })
    pdf = EN16931::PDF.render(@invoice, branding:)
    reader = ::PDF::Reader.new(StringIO.new(pdf))
    fonts = reader.objects.values.select { |o| o.is_a?(Hash) && o[:Type] == :Font }
    assert fonts.all? { |f| f[:BaseFont].to_s.include?("DejaVuSans-Bold") }, fonts.map { |f| f[:BaseFont] }.inspect
  end

  def test_custom_prawn_document_can_be_attached
    doc = Prawn::Document.new
    doc.font_families.update("DejaVu" => { normal: EN16931.font_path("DejaVuSans.ttf") })
    doc.font("DejaVu") { doc.text "Hello" }
    EN16931::PDF::A3.attach(doc, EN16931::XML.cii(@invoice), profile: :en16931, title: "x", author: "y")
    pdf = doc.render
    assert_includes pdf, "<fx:ConformanceLevel>EN 16931</fx:ConformanceLevel>"
    assert_includes pdf, "<fx:DocumentFileName>factur-x.xml</fx:DocumentFileName>"
  end

  def test_long_payment_terms_keep_clear_of_the_giro_code
    terms = "Bitte überweisen Sie den vollständigen Betrag unter Angabe der Rechnungsnummer auf das unten genannte Konto. " * 2
    invoice = EN16931::Invoice.new(**Fixtures.base(payment: @invoice.payment.with(terms:)))
    page = ::PDF::Reader.new(StringIO.new(EN16931::PDF.render(invoice))).pages.first
    code_left = 595.28 - 50 - EN16931::PDF::Renderer::GIRO_CODE_SIZE
    widest = page.runs.select { |run| run.text.include?("Rechnungsnummer auf") }.map(&:endx).max
    assert widest < code_left, "terms end at #{widest}, the GiroCode starts at #{code_left}"
  end

  def test_buyer_contact_and_vat_id_are_printed
    buyer = Fixtures::BUYER_DE.with(contact_name: "Jana Einkauf")
    text = page_text(EN16931::Invoice.new(**Fixtures.base(buyer:)))
    assert_includes text, "z. Hd. Jana Einkauf"
    assert_includes text, "USt-IdNr. DE987654321"
  end

  def test_contact_equal_to_the_buyer_name_is_not_repeated
    buyer = Fixtures::BUYER_DE.with(contact_name: Fixtures::BUYER_DE.name)
    refute_includes page_text(EN16931::Invoice.new(**Fixtures.base(buyer:))), "z. Hd."
  end

  def test_buyer_vat_id_is_left_out_outside_the_scope_of_vat
    buyer = Fixtures::BUYER_DE.with(country: "CH", vat_id: "CHE-123.456.789 MWST")
    text = page_text(EN16931::Invoice.new(**Fixtures.base(buyer:, tax: EN16931::DE.not_taxable_abroad)))
    refute_includes text, "CHE-123.456.789"
  end

  def test_references_are_printed_in_the_header
    invoice = EN16931::Invoice.new(**Fixtures.base(references: { "Kostenstelle" => "4711", "Bestellnummer" => "B-99" }))
    page = ::PDF::Reader.new(StringIO.new(EN16931::PDF.render(invoice))).pages.first
    reference = page.runs.find { |run| run.text == "PO-4711" }
    cost_centre = page.runs.find { |run| run.text == "4711" }
    assert_operator cost_centre.y, :<, reference.y
    assert_includes page.text, "Bestellnummer"
  end

  private

  def page_text(invoice) = ::PDF::Reader.new(StringIO.new(EN16931::PDF.render(invoice))).pages.first.text
end
