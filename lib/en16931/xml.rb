# frozen_string_literal: true

require "nokogiri"

module EN16931
  # The invoice as UN/CEFACT CII XML, by default in the XRechnung profile
  # (the German CIUS of EN 16931, which every German business must be able
  # to receive and which a ZUGFeRD "XRECHNUNG" hybrid carries unchanged).
  #
  # The element tree comes from zugpferd; the few things its writer does not
  # cover yet (tax number with scheme FC, BIC and account name, the invoicing
  # period, the preceding invoice of a correction) are added here.
  module XML
    NS = {
      "rsm" => "urn:un:unece:uncefact:data:standard:CrossIndustryInvoice:100",
      "ram" => "urn:un:unece:uncefact:data:standard:ReusableAggregateBusinessInformationEntity:100",
      "udt" => "urn:un:unece:uncefact:data:standard:UnqualifiedDataType:100"
    }.freeze

    module_function

    # @param profile [:xrechnung, :en16931] the guideline the XML claims (BT-24)
    # @return [String] UTF-8 XML
    def cii(invoice, profile: :xrechnung)
      document = to_zugpferd(invoice, profile:)
      xml = Zugpferd::CII::Writer.new.write(document)
      Extensions.apply(xml, invoice)
    end

    def guideline(profile)
      case profile
      when :xrechnung then XRECHNUNG_GUIDELINE
      when :en16931 then EN16931_GUIDELINE
      else raise ArgumentError, "unknown profile #{profile.inspect}"
      end
    end

    # Maps the invoice onto zugpferd's EN 16931 model.
    def to_zugpferd(invoice, profile: :xrechnung)
      totals = invoice.totals
      klass = { "380" => Zugpferd::Model::Invoice, "381" => Zugpferd::Model::CreditNote,
                "384" => Zugpferd::Model::CorrectedInvoice, "389" => Zugpferd::Model::SelfBilledInvoice,
                "326" => Zugpferd::Model::PartialInvoice, "386" => Zugpferd::Model::PrepaymentInvoice }.fetch(invoice.type_code)
      doc = klass.new(number: invoice.number, issue_date: invoice.issue_date, currency_code: invoice.currency)
      doc.customization_id = guideline(profile)
      doc.profile_id = PEPPOL_BILLING_PROCESS
      doc.due_date = invoice.due_date
      doc.delivery_date = invoice.delivery_date
      doc.buyer_reference = invoice.buyer_reference
      notes = invoice.references.map { |name, value| "#{name}: #{value}" } + invoice.notes
      doc.note = notes.join("\n") unless notes.empty?
      hide_vat_ids = invoice.taxes.any?(&:forbids_vat_identifiers?)
      doc.seller = party(invoice.seller, vat_identifier: !hide_vat_ids, seller: true)
      doc.buyer = party(invoice.buyer, vat_identifier: !hide_vat_ids)
      doc.line_items = invoice.lines.each_with_index.map { |line, i| line_item(invoice, line, i + 1) }
      doc.allowance_charges = (invoice.allowances + invoice.charges).map { |ac| allowance_charge(invoice, ac) }
      doc.tax_breakdown = tax_breakdown(invoice, totals)
      doc.monetary_totals = Zugpferd::Model::MonetaryTotals.new(
        line_extension_amount: totals.line_total, tax_exclusive_amount: totals.net,
        tax_inclusive_amount: totals.gross, payable_amount: totals.payable,
        allowance_total_amount: (totals.allowance_total if totals.allowance_total.positive?),
        charge_total_amount: (totals.charge_total if totals.charge_total.positive?),
        prepaid_amount: (totals.prepaid if totals.prepaid.positive?)
      )
      doc.payment_instructions = payment_instructions(invoice)
      doc
    end

    # A seller without a VAT id on the invoice (Kleinunternehmer, category O)
    # still has to be identifiable (BR-CO-26): the tax number serves as the
    # seller identifier (BT-29) unless the party carries its own.
    def party(party, vat_identifier: true, seller: false)
      vat_id = (party.vat_id if vat_identifier)
      identifier = party.identifier || (party.tax_number if seller && vat_id.nil?)
      Zugpferd::Model::TradeParty.new(
        name: party.name,
        identifier: identifier,
        legal_registration_id: party.registration_id,
        trading_name: party.trading_name,
        legal_form: party.legal_form,
        vat_identifier: vat_id,
        electronic_address: party.electronic_address_value,
        electronic_address_scheme: party.electronic_address_scheme_value,
        postal_address: Zugpferd::Model::PostalAddress.new(
          country_code: party.country, street_name: party.street, city_name: party.city, postal_zone: party.postal_code
        ),
        contact: contact(party)
      )
    end

    def contact(party)
      return nil if party.contact_name.nil? && party.phone.nil? && party.email.nil?

      Zugpferd::Model::Contact.new(name: party.contact_name || party.name, telephone: party.phone, email: party.email)
    end

    def line_item(invoice, line, position)
      tax = invoice.tax_for(line)
      Zugpferd::Model::LineItem.new(
        id: position.to_s, invoiced_quantity: line.quantity, unit_code: line.unit, line_extension_amount: line.net,
        note: line.note,
        item: Zugpferd::Model::Item.new(name: line.description, sellers_identifier: line.sellers_id,
                                        tax_category: tax.category, tax_percent: tax.rate_for_xml),
        price: Zugpferd::Model::Price.new(amount: line.unit_price)
      )
    end

    def allowance_charge(invoice, ac)
      tax = ac.tax || invoice.tax
      Zugpferd::Model::AllowanceCharge.new(
        charge_indicator: ac.charge?, amount: ac.amount, reason: ac.reason, reason_code: ac.reason_code,
        tax_category_code: tax.category, tax_percent: tax.rate_for_xml, currency_code: invoice.currency
      )
    end

    def tax_breakdown(invoice, totals)
      breakdown = Zugpferd::Model::TaxBreakdown.new(tax_amount: totals.vat, currency_code: invoice.currency)
      breakdown.subtotals = totals.subtotals.map do |sub|
        Zugpferd::Model::TaxSubtotal.new(
          taxable_amount: sub.taxable, tax_amount: sub.amount, category_code: sub.tax.category,
          percent: sub.tax.rate, currency_code: invoice.currency, # BT-119 always (BR-DE-14), also for O
          exemption_reason: sub.tax.exemption_reason, exemption_reason_code: sub.tax.exemption_code
        )
      end
      breakdown
    end

    def payment_instructions(invoice)
      payment = invoice.payment
      return nil if payment.nil?

      Zugpferd::Model::PaymentInstructions.new(
        payment_means_code: payment.means_code, account_id: payment.iban, payment_id: payment.reference, note: payment.terms
      )
    end

    # Elements zugpferd's writer leaves out, inserted at their schema position.
    module Extensions
      module_function

      def apply(xml, invoice)
        doc = Nokogiri::XML(xml, &:noblanks)
        add_seller_tax_number(doc, invoice)
        add_bank_details(doc, invoice)
        add_billing_period(doc, invoice)
        add_preceding_invoice(doc, invoice)
        doc.to_xml(indent: 2, encoding: "UTF-8")
      end

      # BT-32 seller tax registration (scheme FC). XRechnung wants a VAT id
      # or a tax number; category O forbids the VAT id, so the number is the
      # only way to identify a Kleinunternehmer or a seller invoicing abroad.
      def add_seller_tax_number(doc, invoice)
        number = invoice.seller.tax_number
        return if number.nil?

        seller = doc.at_xpath("//ram:SellerTradeParty", NS)
        reg = Nokogiri::XML::Node.new("ram:SpecifiedTaxRegistration", doc)
        id = Nokogiri::XML::Node.new("ram:ID", doc)
        id["schemeID"] = "FC"
        id.content = number
        reg.add_child(id)
        seller.add_child(reg)
      end

      # BT-85 account name, BT-86 BIC: after the IBAN.
      def add_bank_details(doc, invoice)
        payment = invoice.payment
        return if payment.nil? || payment.iban.nil?

        account = doc.at_xpath("//ram:PayeePartyCreditorFinancialAccount", NS)
        if payment.holder
          name = Nokogiri::XML::Node.new("ram:AccountName", doc)
          name.content = payment.holder
          account.add_child(name)
        end
        return if payment.bic.nil?

        inst = Nokogiri::XML::Node.new("ram:PayeeSpecifiedCreditorFinancialInstitution", doc)
        bic = Nokogiri::XML::Node.new("ram:BICID", doc)
        bic.content = payment.bic
        inst.add_child(bic)
        account.add_next_sibling(inst)
      end

      # BG-14 invoicing period: after the last ApplicableTradeTax.
      def add_billing_period(doc, invoice)
        period = invoice.period
        return if period.nil?

        node = Nokogiri::XML::Node.new("ram:BillingSpecifiedPeriod", doc)
        node.add_child(date_time(doc, "ram:StartDateTime", period.begin))
        node.add_child(date_time(doc, "ram:EndDateTime", period.end))
        doc.xpath("//ram:ApplicableHeaderTradeSettlement/ram:ApplicableTradeTax", NS).last.add_next_sibling(node)
      end

      # BG-3 preceding invoice reference: after the monetary summation.
      def add_preceding_invoice(doc, invoice)
        preceding = invoice.preceding
        return if preceding.nil?

        node = Nokogiri::XML::Node.new("ram:InvoiceReferencedDocument", doc)
        id = Nokogiri::XML::Node.new("ram:IssuerAssignedID", doc)
        id.content = preceding.fetch(:number)
        node.add_child(id)
        node.add_child(date_time(doc, "ram:FormattedIssueDateTime", preceding[:issue_date], qualified: true)) if preceding[:issue_date]
        doc.at_xpath("//ram:SpecifiedTradeSettlementHeaderMonetarySummation", NS).add_next_sibling(node)
      end

      def date_time(doc, name, date, qualified: false)
        wrapper = Nokogiri::XML::Node.new(name, doc)
        inner = Nokogiri::XML::Node.new(qualified ? "qdt:DateTimeString" : "udt:DateTimeString", doc)
        inner["format"] = "102"
        inner.content = date.strftime("%Y%m%d")
        wrapper.add_child(inner)
        wrapper
      end
    end
  end
end
