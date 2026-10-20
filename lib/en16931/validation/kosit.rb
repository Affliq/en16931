# frozen_string_literal: true

require "open3"
require "tmpdir"
require "fileutils"
require "nokogiri"
require "net/http"
require "uri"

module EN16931
  module Validation
    # The KoSIT validator with the XRechnung configuration: XML Schema and
    # the EN 16931 + XRechnung Schematron rules for UBL and CII. Needs Java 11+.
    #
    #   kosit = EN16931::Validation::KoSIT.new            # tmp/kosit by default
    #   kosit.install!                                    # downloads jar and configuration once
    #   report = kosit.validate(xml)                      # => Report
    class KoSIT
      VALIDATOR_VERSION = "1.6.3"
      CONFIGURATION = "2026-08-31"
      XRECHNUNG = "3.0.2"
      VALIDATOR_URL = "https://repo1.maven.org/maven2/org/kosit/validator/#{VALIDATOR_VERSION}/validator-#{VALIDATOR_VERSION}-standalone.jar".freeze
      CONFIGURATION_URL = "https://github.com/itplr-kosit/validator-configuration-xrechnung/releases/download/v#{CONFIGURATION}/xrechnung-#{XRECHNUNG}-validator-configuration-#{CONFIGURATION}.zip".freeze
      REPORT_NS = { "rep" => "http://www.xoev.de/de/validator/varl/1", "s" => "http://www.xoev.de/de/validator/framework/1/scenarios" }.freeze

      attr_reader :dir

      def initialize(dir: ENV.fetch("EN16931_KOSIT_DIR", "tmp/kosit"), java: ENV.fetch("JAVA", "java"))
        @dir = File.expand_path(dir)
        @java = java
      end

      def jar = File.join(dir, "validator-#{VALIDATOR_VERSION}-standalone.jar")
      def scenarios = File.join(dir, "config", "scenarios.xml")
      def installed? = File.exist?(jar) && File.exist?(scenarios)

      def self.available?(java: "java")
        _, status = Open3.capture2e(java, "-version")
        status.success?
      rescue Errno::ENOENT
        false
      end

      def install!
        FileUtils.mkdir_p(dir)
        download(VALIDATOR_URL, jar) unless File.exist?(jar)
        unless File.exist?(scenarios)
          zip = File.join(dir, "configuration.zip")
          download(CONFIGURATION_URL, zip)
          FileUtils.mkdir_p(File.join(dir, "config"))
          system("unzip", "-q", "-o", zip, "-d", File.join(dir, "config"), exception: true)
        end
        self
      end

      # @param xml [String]
      # @return [Report]
      def validate(xml)
        install! unless installed?
        Dir.mktmpdir("en16931") do |tmp|
          input = File.join(tmp, "invoice.xml")
          File.write(input, xml)
          out, status = Open3.capture2e(@java, "-jar", jar, "-s", scenarios, "-r", File.join(dir, "config"), "-o", tmp, input)
          report_path = File.join(tmp, "invoice-report.xml")
          raise Error, "KoSIT validator produced no report (exit #{status.exitstatus}):\n#{out}" unless File.exist?(report_path)

          parse(File.read(report_path), out)
        end
      end

      private

      def parse(report_xml, console)
        doc = Nokogiri::XML(report_xml)
        accepted = doc.at_xpath("//rep:assessment/rep:accept", REPORT_NS)
        messages = doc.xpath("//rep:message", REPORT_NS).map do |m|
          level = m["level"] == "error" ? :error : :warning
          Message.new(level: level, code: m["code"] || m["id"], text: m.text.strip)
        end
        Report.new(tool: "KoSIT #{VALIDATOR_VERSION} / XRechnung #{XRECHNUNG} (#{CONFIGURATION})", valid: !accepted.nil?, messages: messages,
                   raw: "#{console}\n#{report_xml}")
      end

      def download(url, target)
        uri = URI(url)
        10.times do
          response = Net::HTTP.get_response(uri)
          case response
          when Net::HTTPRedirection then uri = URI(response["location"])
          when Net::HTTPSuccess
            File.binwrite(target, response.body)
            return
          else raise Error, "download of #{url} failed: #{response.code}"
          end
        end
        raise Error, "too many redirects for #{url}"
      end
    end
  end
end
