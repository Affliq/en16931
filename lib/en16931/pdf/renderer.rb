# frozen_string_literal: true

module EN16931
  module PDF
    # The reference layout: an A4 letter with every § 14 UStG item in its
    # place, dressed by a Branding (logo, accent, typeface, texts, GiroCode).
    # Applications with their own design draw their own Prawn document and
    # call A3.attach; this one is the default and the test bed.
    class Renderer
      FONT = "DejaVuSans"
      BRAND_FONT = "Brand"
      # The recipient block starts 45 mm below the page top (DIN 5008 window), unless the letterhead runs deeper.
      ADDRESS_TOP = 45 * 72 / 25.4
      GIRO_CODE_SIZE = 68

      attr_reader :invoice, :locale, :branding

      def self.title(invoice, locale) = "#{LABELS.fetch(self.locale(locale))[invoice.type]} #{invoice.number}"

      def initialize(invoice, locale: :de, branding: Branding.new)
        @invoice = invoice
        @locale = Renderer.locale(locale)
        @branding = branding
        @accent = branding.accent
      end

      def t(key) = LABELS.fetch(locale).fetch(key)

      # @return [Prawn::Document]
      def document
        @document ||= Prawn::Document.new(page_size: "A4", margin: [56, 50, 56, 50], compress: true, info: {}).tap do |pdf|
          pdf.font_families.update(FONT => { normal: EN16931.font_path("DejaVuSans.ttf"), bold: EN16931.font_path("DejaVuSans-Bold.ttf") })
          if branding.font
            pdf.font_families.update(BRAND_FONT => branding.font)
            # Glyphs the brand font lacks (often € in a subset) come from DejaVu, never as .notdef.
            pdf.fallback_fonts([FONT])
          end
          pdf.font(branding.font ? BRAND_FONT : FONT, size: 9.5)
          draw(pdf)
        end
      end

      private

      def draw(pdf)
        letterhead(pdf)
        addresses(pdf)
        meta(pdf)
        intro(pdf)
        lines_table(pdf)
        totals_block(pdf)
        notes(pdf)
        payment_block(pdf)
        closing(pdf)
        footer(pdf)
      end

      # The seller's name, and the logo beside it when there is one. The
      # logo keeps its aspect ratio and the name moves to the other side.
      def letterhead(pdf)
        top = pdf.cursor
        name_align = :left
        if (size = branding.logo_size)
          width, height = size
          x = branding.logo_position == :left ? pdf.bounds.left : pdf.bounds.right - width
          pdf.image(StringIO.new(branding.logo), at: [x, top], width: width, height: height)
          name_align = :right if branding.logo_position == :left
        end
        pdf.text invoice.seller.name, size: 14, style: :bold, align: name_align
        pdf.move_cursor_to [pdf.cursor, top - (size ? size[1] : 0)].min
        pdf.move_down 16
      end

      # Return address in one small line, then the recipient: a letter that
      # fits a window envelope.
      def addresses(pdf)
        seller = invoice.seller
        pdf.move_cursor_to [pdf.cursor, pdf.bounds.top - ADDRESS_TOP + 56].min
        sender = [seller.name, seller.street, seller.address_line_2, [seller.postal_code, seller.city].compact.join(" ")].compact.reject(&:empty?)
        pdf.text sender.join(" · "), size: 7, color: "666666"
        pdf.move_down 6
        buyer = invoice.buyer
        pdf.text buyer.name, style: :bold
        buyer.address_lines.each { |line| pdf.text line }
        pdf.text country_name(buyer.country) unless buyer.country == invoice.seller.country
        pdf.move_down 28
      end

      def meta(pdf)
        pdf.text Renderer.title(invoice, locale), size: 16, style: :bold, color: @accent
        pdf.move_down 8
        rows = [[t(:number), invoice.number], [t(:date), date(invoice.issue_date)]]
        rows << [t(:due), date(invoice.due_date)] if invoice.due_date
        rows << [t(:delivery), date(invoice.delivery_date)] if invoice.delivery_date
        rows << [t(:period), "#{date(invoice.period.begin)} – #{date(invoice.period.end)}"] if invoice.period
        rows << [t(:reference), invoice.buyer_reference] if invoice.buyer_reference
        if invoice.preceding
          rows << [t(:preceding),
                   [invoice.preceding[:number], (date(invoice.preceding[:issue_date]) if invoice.preceding[:issue_date])].compact.join(", ")]
        end
        pdf.table(rows, cell_style: { borders: [], padding: [2, 0], size: 9.5 }, column_widths: [130, 250]) do
          column(0).text_color = "666666"
        end
        pdf.move_down 18
      end

      def intro(pdf)
        return unless branding.intro

        pdf.text branding.intro, size: 9.5
        pdf.move_down 12
      end

      def closing(pdf)
        return unless branding.closing

        pdf.move_down 18
        pdf.text branding.closing, size: 9.5
      end

      def lines_table(pdf)
        header = [t(:pos), t(:description), t(:qty), t(:unit_price), t(:net)]
        rows = invoice.lines.each_with_index.map do |line, i|
          [i + 1, [line.description, line.note, line.period && "#{date(line.period.begin)} – #{date(line.period.end)}"].compact.join("\n"),
           "#{number(line.quantity, 0..2)} #{unit(line.unit)}", money(line.unit_price), money(line.net)]
        end
        pdf.table([header] + rows, width: pdf.bounds.width, column_widths: { 0 => 32, 2 => 80, 3 => 80, 4 => 80 },
                                   cell_style: { borders: [:bottom], border_color: "DDDDDD", padding: [6, 4], size: 9.5 }) do
          row(0).font_style = :bold
          row(0).border_color = @accent
          columns(2..4).align = :right
          column(0).align = :right
        end
        pdf.move_down 10
      end

      def totals_block(pdf)
        totals = invoice.totals
        rows = []
        rows << [t(:sum_net), money(totals.line_total)] unless totals.line_total == totals.net
        invoice.allowances.each { |a| rows << ["#{t(:allowance)} #{a.reason}", "−#{money(a.amount)}"] }
        invoice.charges.each { |c| rows << ["#{t(:charge)} #{c.reason}", money(c.amount)] }
        rows << [t(:net), money(totals.net)]
        totals.subtotals.each do |sub|
          rows << ["#{t(:vat)} #{number(sub.tax.rate, 0..1)} %", money(sub.amount)] if sub.tax.taxed?
        end
        rows << [t(:gross), money(totals.gross)]
        rows << [t(:prepaid), "−#{money(totals.prepaid)}"] if totals.prepaid.positive?
        rows << [t(:payable), money(totals.payable)]
        pdf.indent(pdf.bounds.width - 260) do
          pdf.table(rows, column_widths: [160, 100], cell_style: { borders: [], padding: [3, 4], size: 9.5 }) do
            column(1).align = :right
            row(-1).font_style = :bold
            row(-1).borders = [:top]
            row(-1).border_color = @accent
          end
        end
        pdf.move_down 14
      end

      # Exemption reasons are mandatory text on the invoice; invoice notes follow.
      def notes(pdf)
        texts = invoice.totals.subtotals.map { |s| s.tax.exemption_reason }.compact.uniq + invoice.notes
        texts.each { |text| pdf.text text, size: 9 }
        pdf.move_down 14 unless texts.empty?
      end

      def payment_block(pdf)
        payment = invoice.payment
        return if payment.nil?

        code_bottom = giro_code(pdf)
        pdf.text t(:payment), style: :bold
        pdf.move_down 3
        pdf.text payment.terms, size: 9 if payment.terms
        rows = []
        rows << [t(:holder), payment.holder] if payment.holder
        rows << [t(:iban), payment.iban.scan(/.{1,4}/).join(" ")] if payment.iban
        rows << [t(:bic), payment.bic] if payment.bic
        rows << [t(:reference_line), payment.reference] if payment.reference
        unless rows.empty?
          pdf.table(rows, cell_style: { borders: [], padding: [2, 0], size: 9.5 }, column_widths: [130, 280]) do
            column(0).text_color = "666666"
          end
        end
        pdf.move_cursor_to [pdf.cursor, code_bottom].min if code_bottom
      end

      # The GiroCode floats at the right of the payment details and reports
      # where it ends so the text below does not run into it.
      def giro_code(pdf)
        return nil unless branding.giro_code

        payload = GiroCode.payload(invoice, remittance: Renderer.title(invoice, locale))
        return nil unless payload

        top = pdf.cursor
        pdf.float do
          pdf.bounding_box([pdf.bounds.right - GIRO_CODE_SIZE, top], width: GIRO_CODE_SIZE) do
            GiroCode.draw(pdf, payload, size: GIRO_CODE_SIZE)
            pdf.move_down 3
            pdf.text t(:giro_code), size: 7, color: "666666", align: :center
          end
        end
        top - GIRO_CODE_SIZE - 14
      end

      def footer(pdf)
        seller = invoice.seller
        ids = []
        ids << "#{t(:vat_id)} #{seller.vat_id}" if seller.vat_id
        ids << "#{t(:tax_number)} #{seller.tax_number}" if seller.tax_number
        contact = [seller.contact_name, seller.phone, seller.email].compact.join(" · ")
        pdf.repeat(:all) do
          pdf.bounding_box([pdf.bounds.left, pdf.bounds.bottom + 26], width: pdf.bounds.width) do
            pdf.stroke_color "DDDDDD"
            pdf.stroke_horizontal_rule
            pdf.move_down 6
            pdf.text [seller.name, seller.legal_form, ids.join(" · "), ("#{t(:contact)}: #{contact}" unless contact.empty?)].compact.join("  ·  "), size: 7.5,
                                                                                                                                                    color: "666666"
          end
        end
      end

      def money(amount)
        "#{number(amount, 2..2)} #{currency_symbol}"
      end

      def currency_symbol
        { "EUR" => "€", "USD" => "$", "GBP" => "£", "CHF" => "CHF" }.fetch(invoice.currency, invoice.currency)
      end

      def number(value, decimals)
        text = format("%.#{decimals.max}f", value)
        int, frac = text.split(".")
        frac = frac&.sub(/0+\z/, "") if decimals.min < decimals.max
        frac = nil if frac && frac.empty?
        sep = FORMATS.fetch(locale)
        int = int.reverse.scan(/\d{1,3}/).join(sep[0]).reverse
        [int, frac].compact.join(sep[1])
      end

      def date(d) = d.strftime(FORMATS.fetch(locale)[2])
      def unit(code) = LABELS.fetch(locale)[:units].fetch(code, code)

      def country_name(code)
        { "DE" => "Deutschland", "AT" => "Österreich", "CH" => "Schweiz", "FR" => "Frankreich", "NL" => "Niederlande",
          "US" => "USA", "GB" => "Vereinigtes Königreich", "IE" => "Irland", "LU" => "Luxemburg" }.fetch(code, code)
      end
    end
  end
end
