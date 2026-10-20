# frozen_string_literal: true

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)
require "en16931"
require "minitest/autorun"
require "nokogiri"
require_relative "fixtures/invoices"

module XPathHelpers
  NS = EN16931::XML::NS

  def cii(invoice, **) = Nokogiri::XML(EN16931::XML.cii(invoice, **))
  def text(doc, xpath) = doc.at_xpath(xpath, NS)&.text
end
