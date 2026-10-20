# frozen_string_literal: true

require "test_helper"

# The proof: every fixture passes the official validators. Runs wherever
# Java (KoSIT) and veraPDF or Docker are available; CI always has both.
class ValidationTest < Minitest::Test
  def setup
    @kosit = EN16931::Validation::KoSIT.new
    @vera = EN16931::Validation::VeraPDF.new
    skip "Java not available" unless EN16931::Validation::KoSIT.available?
    @kosit.install!
  end

  Fixtures.all.each_key do |name|
    define_method("test_#{name}_xml_passes_kosit") do
      report = @kosit.validate(EN16931::XML.cii(Fixtures.all[name]))
      assert report.valid?, report.to_s
    end

    define_method("test_#{name}_pdf_passes_verapdf") do
      skip "veraPDF not available" unless @vera.available?
      report = @vera.validate(EN16931::PDF.render(Fixtures.all[name]))
      assert report.valid?, report.to_s
    end
  end
end
