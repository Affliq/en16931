# frozen_string_literal: true

require "digest"
require "zlib"

module EN16931
  module PDF
    # Turns a Prawn document into a PDF/A-3b with the invoice XML embedded,
    # in pure Ruby: PDF 1.7, document identifier, Info dictionary mirrored
    # in XMP, sRGB output intent, the XML as an associated file (AF) with
    # the relationship the profile asks for. Fonts must be TrueType, since
    # PDF/A forbids the unembedded base-14 fonts; the renderer uses DejaVu.
    module A3
      ICC_PROFILE = File.join(ROOT, "icc", "sRGB-v2-micro.icc")
      PRODUCER = "en16931 #{VERSION} (Prawn)".freeze

      # Filename and AF relationship per ZUGFeRD 2.x profile.
      PROFILES = {
        xrechnung: { conformance: "XRECHNUNG", filename: "xrechnung.xml", relationship: :Alternative },
        en16931: { conformance: "EN 16931", filename: "factur-x.xml", relationship: :Alternative },
        extended: { conformance: "EXTENDED", filename: "factur-x.xml", relationship: :Alternative },
        basic: { conformance: "BASIC", filename: "factur-x.xml", relationship: :Alternative }
      }.freeze

      module_function

      # @param pdf [Prawn::Document] a document drawn with embedded TrueType fonts
      # @param xml [String] the CII invoice XML
      # @return [Prawn::Document] the same document, ready to `render`
      def attach(pdf, xml, title:, author:, profile: :xrechnung, created_at: Time.now, creator_tool: PRODUCER, document_type: "INVOICE")
        spec = PROFILES.fetch(profile) { raise ArgumentError, "unknown profile #{profile.inspect}" }
        pdf.renderer.min_version(1.7)
        set_info(pdf, title:, author:, created_at:, creator_tool:)
        set_identifier(pdf, xml, created_at)
        add_output_intent(pdf)
        filespec = embed_file(pdf, xml, spec, created_at)
        pdf.renderer.names.data[:EmbeddedFiles] = pdf.ref!(Names: [::PDF::Core::LiteralString.new(spec[:filename]), filespec])
        pdf.state.store.root.data[:AF] = [filespec]
        add_metadata(pdf, XMP.build(title:, author:, created_at:, producer: PRODUCER, creator_tool:,
                                    filename: spec[:filename], conformance: spec[:conformance], document_type:))
        pdf
      end

      def set_info(pdf, title:, author:, created_at:, creator_tool:)
        pdf.state.store.info.data.merge!(
          Title: title, Author: author, Creator: creator_tool, Producer: PRODUCER,
          CreationDate: created_at, ModDate: created_at
        )
      end

      # PDF/A-2 and -3 require the file identifier in the trailer.
      def set_identifier(pdf, xml, created_at)
        id = ::PDF::Core::LiteralString.new(Digest::MD5.digest("#{xml}#{created_at.to_f}"))
        pdf.state.trailer[:ID] = [id, id]
      end

      # DeviceRGB content needs an output intent; sRGB covers screens and print.
      def add_output_intent(pdf)
        icc = pdf.ref!(N: 3)
        icc << File.binread(ICC_PROFILE)
        icc.stream.compress!
        intent = pdf.ref!(
          Type: :OutputIntent, S: :GTS_PDFA1,
          OutputConditionIdentifier: ::PDF::Core::LiteralString.new("sRGB"),
          Info: ::PDF::Core::LiteralString.new("sRGB IEC61966-2.1"),
          RegistryName: ::PDF::Core::LiteralString.new("http://www.color.org"),
          DestOutputProfile: icc
        )
        pdf.state.store.root.data[:OutputIntents] = [intent]
      end

      def embed_file(pdf, xml, spec, created_at)
        bytes = xml.b
        file = pdf.ref!(Type: :EmbeddedFile, Subtype: :"text/xml", Params: { ModDate: created_at, Size: bytes.bytesize })
        file << bytes
        file.stream.compress!
        pdf.ref!(
          Type: :Filespec, F: ::PDF::Core::LiteralString.new(spec[:filename]), UF: spec[:filename],
          Desc: "Invoice data (EN 16931, #{spec[:conformance]})", AFRelationship: spec[:relationship],
          EF: { F: file, UF: file }
        )
      end

      # XMP goes in uncompressed so any reader can find it.
      def add_metadata(pdf, xmp)
        metadata = pdf.ref!(Type: :Metadata, Subtype: :XML)
        metadata << xmp.b
        pdf.state.store.root.data[:Metadata] = metadata
      end
    end
  end
end
