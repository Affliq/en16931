# frozen_string_literal: true

require "prawn"

module EN16931
  # How the reference layout looks for one seller: a logo, an accent colour,
  # an own typeface, an opening and a closing line, the GiroCode. All optional;
  # `Branding.new` is the plain layout. Everything here stays inside PDF/A-3b:
  # fonts are embedded, images are RGB, the QR code is drawn as vectors.
  #
  # @param logo [String, IO, nil] a PNG or JPEG: a path, the file's bytes, or an IO
  # @param logo_position [:left, :right] where the logo sits in the letterhead
  # @param logo_height [Numeric] the logo's height in points (its width follows, capped at logo_max_width)
  # @param accent [String] six hex digits, used for the title and the rules
  # @param font [String, Hash, nil] a TrueType file, or { normal:, bold: } paths; DejaVu Sans otherwise
  # @param title_font [String, nil] a TrueType file for the document title alone, e.g. a display face that has
  #   no bold cut; the title is then set in it as it is, not emboldened. The body keeps `font`.
  # @param title_color [String, nil] six hex digits for the title; the accent otherwise
  # @param letterhead_name [Boolean] print the seller's name in the letterhead; turn it off when the logo is
  #   the name (a wordmark). Without a logo the name is always printed.
  # @param intro [String, nil] text above the lines, e.g. a salutation
  # @param closing [String, nil] text below the payment details, e.g. thanks and a signature line
  # @param giro_code [Boolean] print the EPC QR code (GiroCode) next to the bank details when the invoice can carry one
  Branding = Data.define(:logo, :logo_position, :logo_height, :logo_max_width, :accent, :font, :intro, :closing, :giro_code,
                         :title_font, :title_color, :letterhead_name) do
    def initialize(logo: nil, logo_position: :left, logo_height: 40, logo_max_width: 180, accent: "15161A", font: nil,
                   intro: nil, closing: nil, giro_code: true, title_font: nil, title_color: nil, letterhead_name: true)
      raise ArgumentError, "logo_position must be :left or :right" unless %i[left right].include?(logo_position)
      raise ArgumentError, "accent must be six hex digits, e.g. \"FF5A1F\"" unless accent.to_s.match?(/\A\h{6}\z/)
      raise ArgumentError, "title_color must be six hex digits, e.g. \"15161A\"" unless title_color.nil? || title_color.to_s.match?(/\A\h{6}\z/)
      raise ArgumentError, "title_font must be the path of a TrueType file" unless title_font.nil? || title_font.is_a?(String)

      super(logo: Branding.image_bytes(logo), logo_position:, logo_height:, logo_max_width:, accent: accent.to_s.upcase,
            font: Branding.font_files(font), intro:, closing:, giro_code:, title_font:,
            title_color: title_color&.to_s&.upcase, letterhead_name: letterhead_name ? true : false)
      logo_info # fail at construction, not at render time
    end

    # The colour the title is printed in.
    def title_colour = title_color || accent

    # The seller's name belongs in the letterhead unless a logo stands in for it.
    def letterhead_name? = letterhead_name || logo.nil?

    # The parsed image: width, height and, for a JPEG, the channel count.
    # CMYK images would need a CMYK output intent, so they are refused.
    def logo_info
      return nil unless logo

      Prawn.image_handler.find(logo).new(logo).tap do |info|
        raise ArgumentError, "CMYK JPEG logos are not PDF/A-safe with the sRGB output intent; use an RGB image" if info.respond_to?(:channels) && info.channels == 4
        raise ArgumentError, "interlaced PNGs are not supported; export the logo without interlacing" if info.respond_to?(:interlace_method) && info.interlace_method != 0
      end
    end

    # The logo's drawn size: scaled to logo_height, narrower if it would exceed logo_max_width.
    def logo_size
      info = logo_info
      return nil unless info

      scale = [logo_height.to_f / info.height, logo_max_width.to_f / info.width].min
      [info.width * scale, info.height * scale]
    end

    # The logo bytes are not worth printing.
    def inspect = "#<data EN16931::Branding #{to_h.merge(logo: logo && "<#{logo.bytesize} bytes>").map { |k, v| "#{k}=#{v.inspect}" }.join(", ")}>"

    def self.image_bytes(logo)
      case logo
      when nil then nil
      when String
        logo.b.start_with?("\x89PNG".b, "\xFF\xD8".b) ? logo.b : File.binread(logo)
      else
        logo.rewind if logo.respond_to?(:rewind)
        logo.read.b
      end
    end

    def self.font_files(font)
      case font
      when nil then nil
      when String then { normal: font, bold: font }
      when Hash
        normal = font[:normal] || font["normal"] or raise ArgumentError, "font needs at least a :normal file"
        { normal:, bold: font[:bold] || font["bold"] || normal }
      else raise ArgumentError, "font must be a file path or { normal:, bold: }"
      end
    end
  end
end
