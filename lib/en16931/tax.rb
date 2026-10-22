# frozen_string_literal: true

module EN16931
  # A VAT treatment (BG-23 / BT-151): the category code, the rate, and for
  # exempt categories the reason text (BT-120) and code (BT-121).
  #
  # Categories per UNTDID 5305 as used by EN 16931:
  #   S  standard rate          Z  zero rated            E  exempt
  #   AE reverse charge         K  intra-community       G  export outside the EU
  #   O  not subject to VAT     L/M Canary Islands / Ceuta-Melilla (unused here)
  Tax = Data.define(:category, :rate, :exemption_reason, :exemption_code) do
    def initialize(category:, rate: 0, exemption_reason: nil, exemption_code: nil)
      super(category: category.to_s, rate: EN16931.decimal(rate), exemption_reason:, exemption_code:)
    end

    def taxed? = category == "S"
    def exempt? = !taxed? && category != "Z"

    # Category O forbids a seller VAT identifier on the invoice (BR-O-2);
    # the seller is identified by the tax number instead.
    def forbids_vat_identifiers? = category == "O"

    # Lines, allowances and charges in category O carry no rate (BR-O-05 to
    # BR-O-07); every other exempt category carries an explicit 0.
    def rate_for_xml = category == "O" ? nil : rate

    def self.standard(rate) = new(category: "S", rate: rate)
    def self.zero_rated = new(category: "Z")
    def self.exempt(reason:, code: nil) = new(category: "E", exemption_reason: reason, exemption_code: code)
    def self.reverse_charge(reason:, code: "VATEX-EU-AE") = new(category: "AE", exemption_reason: reason, exemption_code: code)
    def self.intra_community(reason:, code: "VATEX-EU-IC") = new(category: "K", exemption_reason: reason, exemption_code: code)
    def self.export(reason:, code: "VATEX-EU-G") = new(category: "G", exemption_reason: reason, exemption_code: code)
    def self.not_subject(reason:, code: "VATEX-EU-O") = new(category: "O", exemption_reason: reason, exemption_code: code)
  end
end
