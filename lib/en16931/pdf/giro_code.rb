# frozen_string_literal: true

require "rqrcode_core"

module EN16931
  module PDF
    # The EPC QR code ("GiroCode"): scanned by a banking app, it prefills a
    # SEPA credit transfer with the seller's IBAN, the amount and the
    # remittance text. Version 002 of the EPC guideline; euro only.
    module GiroCode
      NAME_LENGTH = 70
      REMITTANCE_LENGTH = 140
      MAX_AMOUNT = BigDecimal("999999999.99")

      module_function

      # @return [String, nil] the payload, or nil when the invoice cannot carry a GiroCode
      def payload(invoice, remittance:)
        payment = invoice.payment
        return nil unless payment&.iban && invoice.currency == "EUR"

        amount = invoice.totals.payable
        return nil unless amount.positive? && amount <= MAX_AMOUNT

        name = (payment.holder || invoice.seller.name).to_s[0, NAME_LENGTH]
        [
          "BCD", "002", "1", "SCT",
          payment.bic.to_s,
          name,
          payment.iban,
          "EUR#{format("%.2f", amount)}",
          "",
          "",
          (payment.reference || remittance).to_s[0, REMITTANCE_LENGTH]
        ].join("\n")
      end

      # Draws the code as filled rectangles (no raster image, no transparency),
      # top-left corner at the current cursor inside the current bounds.
      def draw(pdf, payload, size:)
        qr = RQRCodeCore::QRCode.new(payload, level: :m)
        count = qr.module_count
        unit = size.to_f / count
        x0 = pdf.bounds.left
        y0 = pdf.cursor
        previous = pdf.fill_color
        pdf.fill_color "000000"
        count.times do |row|
          runs(qr, row, count).each do |start, length|
            pdf.fill_rectangle [x0 + (start * unit), y0 - (row * unit)], length * unit, unit
          end
        end
        pdf.fill_color previous
        pdf.move_down size
      end

      # Consecutive dark modules in a row as [start, length] pairs: fewer objects in the PDF.
      def runs(qr, row, count)
        result = []
        col = 0
        while col < count
          if qr.checked?(row, col)
            start = col
            col += 1 while col < count && qr.checked?(row, col)
            result << [start, col - start]
          else
            col += 1
          end
        end
        result
      end
    end
  end
end
