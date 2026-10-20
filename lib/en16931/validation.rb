# frozen_string_literal: true

require_relative "validation/report"
require_relative "validation/kosit"
require_relative "validation/vera_pdf"

module EN16931
  # Wrappers around the official validators, meant for CI and for proving a
  # layout once: KoSIT (the German XRechnung validator, Java) for the XML and
  # veraPDF for the PDF/A-3b container. Neither is needed at run time.
  module Validation
  end
end
