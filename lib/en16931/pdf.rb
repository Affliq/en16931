# frozen_string_literal: true

require "prawn"
require "prawn/table"
require_relative "pdf/xmp"
require_relative "pdf/a3"
require_relative "pdf/renderer"

module EN16931
  # The hybrid: a PDF/A-3b with the invoice XML embedded (ZUGFeRD 2.x /
  # Factur-X). `render` draws the reference layout; `A3.attach` turns any
  # Prawn document into the hybrid.
  module PDF
    module_function

    # @return [String] PDF bytes
    def render(invoice, profile: :xrechnung, locale: :de, created_at: Time.now, **renderer_options)
      xml = XML.cii(invoice, profile:)
      doc = Renderer.new(invoice, locale:, **renderer_options).document
      A3.attach(doc, xml, profile:, title: Renderer.title(invoice, locale), author: invoice.seller.name, created_at:)
      doc.render
    end
  end
end
