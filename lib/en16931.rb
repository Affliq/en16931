# frozen_string_literal: true

require "bigdecimal"
require "bigdecimal/util"
require "date"
require "zugpferd"

# EN 16931 e-invoices for Ruby: a small invoice model, CII XML in the
# XRechnung profile (through zugpferd), a PDF/A-3 hybrid with the XML
# embedded (through Prawn, pure Ruby), German tax presets, and wrappers for
# the official validators (KoSIT, veraPDF).
module EN16931
  class Error < StandardError; end
  class ValidationError < Error; end

  # Guideline identifiers (BT-24) and business process (BT-23).
  XRECHNUNG_GUIDELINE = "urn:cen.eu:en16931:2017#compliant#urn:xeinkauf.de:kosit:xrechnung_3.0"
  EN16931_GUIDELINE = "urn:cen.eu:en16931:2017"
  PEPPOL_BILLING_PROCESS = "urn:fdc:peppol.eu:2017:poacc:billing:01:1.0"

  ROOT = File.expand_path("..", __dir__)

  def self.font_path(name) = File.join(ROOT, "fonts", name)
end

require_relative "en16931/version"
require_relative "en16931/tax"
require_relative "en16931/de"
require_relative "en16931/party"
require_relative "en16931/line"
require_relative "en16931/payment"
require_relative "en16931/invoice"
require_relative "en16931/totals"
require_relative "en16931/xml"
require_relative "en16931/pdf"
require_relative "en16931/validation"
