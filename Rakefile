# frozen_string_literal: true

require "bundler/gem_tasks"
require "minitest/test_task"
require "rubocop/rake_task"

Minitest::TestTask.create
RuboCop::RakeTask.new

task default: %i[test rubocop]

desc "Render every fixture invoice to examples/ as XML and hybrid PDF"
task :examples do
  $LOAD_PATH.unshift File.expand_path("lib", __dir__)
  require "en16931"
  require_relative "test/fixtures/invoices"
  FileUtils.mkdir_p("examples")
  Fixtures.each do |name, invoice|
    File.write("examples/#{name}.xml", EN16931::XML.cii(invoice))
    File.binwrite("examples/#{name}.pdf", EN16931::PDF.render(invoice, created_at: Time.utc(2026, 10, 20, 12)))
    puts "examples/#{name}.{xml,pdf}"
  end
end

desc "Run the official validators (KoSIT for the XML, veraPDF for the PDF) over every fixture"
task :validate do
  $LOAD_PATH.unshift File.expand_path("lib", __dir__)
  require "en16931"
  require_relative "test/fixtures/invoices"
  kosit = EN16931::Validation::KoSIT.new.install!
  vera = EN16931::Validation::VeraPDF.new
  failed = false
  puts "fixture                      KoSIT      veraPDF   "
  Fixtures.each do |name, invoice|
    xml_report = kosit.validate(EN16931::XML.cii(invoice))
    pdf_report = vera.validate(EN16931::PDF.render(invoice))
    puts format("%<name>-28s %<xml>-10s %<pdf>-10s", name: name, xml: xml_report.valid? ? "valid" : "INVALID", pdf: pdf_report.valid? ? "valid" : "INVALID")
    [xml_report, pdf_report].reject(&:valid?).each { |r| puts r.to_s.lines.map { |l| "    #{l}" }.join }
    failed ||= !(xml_report.valid? && pdf_report.valid?)
  end
  abort "validation failed" if failed
end
