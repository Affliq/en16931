# frozen_string_literal: true

require_relative "lib/en16931/version"

Gem::Specification.new do |spec|
  spec.name = "en16931"
  spec.version = EN16931::VERSION
  spec.authors = ["Markus Schwed"]
  spec.email = ["ma.schwed@googlemail.com"]

  spec.summary = "EN 16931 e-invoices for Ruby: XRechnung XML and ZUGFeRD hybrid PDF/A-3, in pure Ruby."
  spec.description = "Build EN 16931 invoices from a small Ruby model, write them as XRechnung (CII) and as a " \
                     "ZUGFeRD/Factur-X hybrid PDF/A-3 with Prawn, with German VAT presets (Regelbesteuerung, " \
                     "Kleinunternehmer, Reverse Charge, Drittland) and wrappers for the official validators."
  spec.homepage = "https://github.com/Affliq/en16931"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.2.0"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage
  spec.metadata["changelog_uri"] = "#{spec.homepage}/blob/main/CHANGELOG.md"
  spec.metadata["bug_tracker_uri"] = "#{spec.homepage}/issues"
  spec.metadata["rubygems_mfa_required"] = "true"

  gemspec = File.basename(__FILE__)
  spec.files = IO.popen(%w[git ls-files -z], chdir: __dir__, err: IO::NULL) do |ls|
    ls.readlines("\x0", chomp: true).reject do |f|
      (f == gemspec) ||
        f.start_with?(*%w[bin/ Gemfile .gitignore test/ .github/ .rubocop.yml examples/])
    end
  end
  spec.require_paths = ["lib"]

  spec.add_dependency "nokogiri", "~> 1.16"
  spec.add_dependency "prawn", "~> 2.5"
  spec.add_dependency "prawn-table", "~> 0.2"
  spec.add_dependency "rqrcode_core", "~> 2.0"
  spec.add_dependency "zugpferd", "~> 0.3"
end
