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
    Fixtures.each do |name, invoice|
      pdf = EN16931::PDF.render(invoice)
      assert pdf.bytesize > 10_000, "#{name} rendered nothing"
      assert_equal 1, ::PDF::Reader.new(StringIO.new(pdf)).page_count, "#{name} should fit on one page"
    end
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
end
