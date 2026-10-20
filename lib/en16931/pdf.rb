# frozen_string_literal: true

require "prawn"
require "stringio"
require "prawn/table"
require_relative "pdf/xmp"
require_relative "pdf/giro_code"
require_relative "pdf/a3"
require_relative "pdf/renderer"

module EN16931
  # The hybrid: a PDF/A-3b with the invoice XML embedded (ZUGFeRD 2.x /
  # Factur-X). `render` draws the reference layout; `A3.attach` turns any
  # Prawn document into the hybrid.
  module PDF
    module_function

    # @param branding [Branding] logo, colour, typeface, texts, GiroCode; the plain layout by default
    # @return [String] PDF bytes
    def render(invoice, profile: :xrechnung, locale: :de, created_at: Time.now, branding: Branding.new)
      xml = XML.cii(invoice, profile:)
      doc = Renderer.new(invoice, locale:, branding:).document
      A3.attach(doc, xml, profile:, title: Renderer.title(invoice, locale), author: invoice.seller.name, created_at:)
      doc.render
    end
  end
end
