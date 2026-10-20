# frozen_string_literal: true

module EN16931
  # Seller (BG-4) or buyer (BG-7). XRechnung needs for the seller a contact
  # (name, phone, email), an electronic address and a VAT id or tax number;
  # for the buyer an electronic address. Email is the electronic address
  # (scheme EM) unless another one is given.
  Party = Data.define(:name, :street, :postal_code, :city, :country, :vat_id, :tax_number, :email, :phone,
                      :contact_name, :legal_form, :registration_id, :trading_name, :electronic_address,
                      :electronic_address_scheme, :identifier, :address_line_2) do
    def initialize(name:, country:, street: nil, postal_code: nil, city: nil, vat_id: nil, tax_number: nil, email: nil,
                   phone: nil, contact_name: nil, legal_form: nil, registration_id: nil, trading_name: nil,
                   electronic_address: nil, electronic_address_scheme: nil, identifier: nil, address_line_2: nil)
      super
    end

    def electronic_address_value = electronic_address || email
    def electronic_address_scheme_value = electronic_address_scheme || "EM"

    # The lines of a postal address as printed.
    def address_lines
      [[postal_code, city].compact.join(" ").then { |s| s.empty? ? nil : s }, street, address_line_2].then do |(place, st, extra)|
        [st, extra, place].compact
      end
    end
  end
end
