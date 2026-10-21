# frozen_string_literal: true

require "test_helper"

class XMLTest < Minitest::Test
  include XPathHelpers

  def test_xrechnung_guideline_and_process
    doc = cii(Fixtures.all[:standard_19])
    assert_equal EN16931::XRECHNUNG_GUIDELINE, text(doc, "//ram:GuidelineSpecifiedDocumentContextParameter/ram:ID")
    assert_equal EN16931::PEPPOL_BILLING_PROCESS, text(doc, "//ram:BusinessProcessSpecifiedDocumentContextParameter/ram:ID")
    assert_equal "380", text(doc, "//rsm:ExchangedDocument/ram:TypeCode")
    assert_equal "PO-4711", text(doc, "//ram:BuyerReference")
    assert_equal "20261020", text(doc, "//rsm:ExchangedDocument/ram:IssueDateTime/udt:DateTimeString")
  end

  def test_plain_en16931_guideline_on_request
    doc = cii(Fixtures.all[:standard_19], profile: :en16931)
    assert_equal EN16931::EN16931_GUIDELINE, text(doc, "//ram:GuidelineSpecifiedDocumentContextParameter/ram:ID")
  end

  def test_seller_carries_contact_electronic_address_vat_id_and_tax_number
    doc = cii(Fixtures.all[:standard_19])
    seller = doc.at_xpath("//ram:SellerTradeParty", NS)
    assert_equal "Lena Beispiel", text(seller, "./ram:DefinedTradeContact/ram:PersonName")
    assert_equal "+49 30 1234567", text(seller, "./ram:DefinedTradeContact/ram:TelephoneUniversalCommunication/ram:CompleteNumber")
    assert_equal "lena@example.com", text(seller, "./ram:URIUniversalCommunication/ram:URIID")
    assert_equal "EM", seller.at_xpath("./ram:URIUniversalCommunication/ram:URIID", NS)["schemeID"]
    assert_equal "DE123456789", text(seller, "./ram:SpecifiedTaxRegistration/ram:ID[@schemeID='VA']")
    assert_equal "30/123/45678", text(seller, "./ram:SpecifiedTaxRegistration/ram:ID[@schemeID='FC']")
    assert_equal "invoices@glowco.example", text(doc, "//ram:BuyerTradeParty/ram:URIUniversalCommunication/ram:URIID")
  end

  def test_small_business_is_category_e_with_the_paragraph_19_note
    doc = cii(Fixtures.all[:small_business])
    tax = doc.at_xpath("//ram:ApplicableHeaderTradeSettlement/ram:ApplicableTradeTax", NS)
    assert_equal "E", text(tax, "./ram:CategoryCode")
    assert_equal 0, text(tax, "./ram:CalculatedAmount").to_d
    assert_includes text(tax, "./ram:ExemptionReason"), "§ 19 UStG"
    assert_nil doc.at_xpath("//ram:SellerTradeParty/ram:SpecifiedTaxRegistration/ram:ID[@schemeID='VA']", NS)
    assert_equal "040/123/45678", text(doc, "//ram:SellerTradeParty/ram:SpecifiedTaxRegistration/ram:ID[@schemeID='FC']")
    assert_equal "040/123/45678", text(doc, "//ram:SellerTradeParty/ram:ID"), "BR-CO-26 needs a seller identifier"
    assert_equal "0", text(doc, "//ram:SpecifiedLineTradeSettlement/ram:ApplicableTradeTax/ram:RateApplicablePercent")
  end

  def test_reverse_charge_names_both_vat_ids_and_the_code
    doc = cii(Fixtures.all[:reverse_charge_eu])
    tax = doc.at_xpath("//ram:ApplicableHeaderTradeSettlement/ram:ApplicableTradeTax", NS)
    assert_equal "AE", text(tax, "./ram:CategoryCode")
    assert_equal "VATEX-EU-AE", text(tax, "./ram:ExemptionReasonCode")
    assert_equal "DE123456789", text(doc, "//ram:SellerTradeParty/ram:SpecifiedTaxRegistration/ram:ID[@schemeID='VA']")
    assert_equal "FR12345678901", text(doc, "//ram:BuyerTradeParty/ram:SpecifiedTaxRegistration/ram:ID[@schemeID='VA']")
  end

  def test_not_taxable_abroad_drops_vat_ids_and_keeps_the_tax_number
    doc = cii(Fixtures.all[:third_country_usd])
    assert_equal "O", text(doc, "//ram:ApplicableHeaderTradeSettlement/ram:ApplicableTradeTax/ram:CategoryCode")
    # BR-DE-14 wants the rate in the breakdown; BR-O-05 forbids it on the line.
    assert_equal "0", text(doc, "//ram:ApplicableHeaderTradeSettlement/ram:ApplicableTradeTax/ram:RateApplicablePercent")
    assert_nil doc.at_xpath("//ram:SpecifiedLineTradeSettlement/ram:ApplicableTradeTax/ram:RateApplicablePercent", NS)
    assert_equal "30/123/45678", text(doc, "//ram:SellerTradeParty/ram:ID")
    assert_empty doc.xpath("//ram:SpecifiedTaxRegistration/ram:ID[@schemeID='VA']", NS)
    assert_equal "30/123/45678", text(doc, "//ram:SellerTradeParty/ram:SpecifiedTaxRegistration/ram:ID[@schemeID='FC']")
    assert_equal "USD", text(doc, "//ram:InvoiceCurrencyCode")
    assert_equal "HUR", doc.at_xpath("//ram:BilledQuantity", NS)["unitCode"]
  end

  def test_extensions_land_at_their_schema_positions
    doc = cii(Fixtures.all[:retainer_period])
    period = doc.at_xpath("//ram:BillingSpecifiedPeriod", NS)
    assert_equal "20261001", text(period, "./ram:StartDateTime/udt:DateTimeString")
    assert_equal "ApplicableTradeTax", period.previous_element.name
    assert_equal "SpecifiedTradePaymentTerms", period.next_element.name

    doc = cii(Fixtures.all[:corrected_invoice])
    assert_equal "384", text(doc, "//rsm:ExchangedDocument/ram:TypeCode")
    ref = doc.at_xpath("//ram:InvoiceReferencedDocument", NS)
    assert_equal "2026-0001", text(ref, "./ram:IssuerAssignedID")
    assert_equal "SpecifiedTradeSettlementHeaderMonetarySummation", ref.previous_element.name

    doc = cii(Fixtures.all[:standard_19])
    account = doc.at_xpath("//ram:PayeePartyCreditorFinancialAccount", NS)
    assert_equal "DE89370400440532013000", text(account, "./ram:IBANID")
    assert_equal "Lena Beispiel", text(account, "./ram:AccountName")
    assert_equal "COBADEFFXXX", text(account.next_element, "./ram:BICID")
    assert_equal "58", text(doc, "//ram:SpecifiedTradeSettlementPaymentMeans/ram:TypeCode")
  end

  def test_totals_and_allowances_in_the_summation
    doc = cii(Fixtures.all[:mixed_rates_discount])
    sum = doc.at_xpath("//ram:SpecifiedTradeSettlementHeaderMonetarySummation", NS)
    assert_equal 1675.to_d, text(sum, "./ram:LineTotalAmount").to_d
    assert_equal 100.to_d, text(sum, "./ram:AllowanceTotalAmount").to_d
    assert_equal 1575.to_d, text(sum, "./ram:TaxBasisTotalAmount").to_d
    assert_equal "296.25".to_d, text(sum, "./ram:TaxTotalAmount").to_d
    assert_equal "1871.25".to_d, text(sum, "./ram:GrandTotalAmount").to_d
    assert_equal "1871.25".to_d, text(sum, "./ram:DuePayableAmount").to_d
    assert_equal "false", text(doc, "//ram:SpecifiedTradeAllowanceCharge/ram:ChargeIndicator/udt:Indicator")
  end

  def test_references_travel_as_notes_ahead_of_the_notes
    invoice = EN16931::Invoice.new(**Fixtures.base(references: { "Kostenstelle" => "4711" }, notes: ["Danke."]))
    assert_equal "Kostenstelle: 4711\nDanke.", text(cii(invoice), "//rsm:ExchangedDocument/ram:IncludedNote/ram:Content")
  end
end
