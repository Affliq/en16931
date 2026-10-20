# frozen_string_literal: true

require "open3"
require "tmpdir"
require "nokogiri"

module EN16931
  module Validation
    # veraPDF, the reference PDF/A validator: the `verapdf` command when it is
    # installed, else the official Docker image.
    class VeraPDF
      IMAGE = "ghcr.io/verapdf/cli:latest"

      def initialize(command: ENV.fetch("VERAPDF", nil), docker: ENV.fetch("DOCKER", "docker"))
        @command = command || (system("which", "verapdf", out: File::NULL) ? "verapdf" : nil)
        @docker = docker
      end

      def self.available?
        new.available?
      end

      def available?
        return true if @command

        _, status = Open3.capture2e(@docker, "image", "inspect", IMAGE)
        status.success? || Open3.capture2e(@docker, "pull", IMAGE).last.success?
      rescue Errno::ENOENT
        false
      end

      # @param pdf [String] PDF bytes
      # @return [Report]
      def validate(pdf, flavour: "3b")
        Dir.mktmpdir("en16931") do |tmp|
          path = File.join(tmp, "invoice.pdf")
          File.binwrite(path, pdf)
          out, = if @command
                   Open3.capture2e(@command, "-f", flavour, "--format", "xml", path)
                 else
                   Open3.capture2e(@docker, "run", "--rm", "-v", "#{tmp}:/data", IMAGE, "-f", flavour, "--format", "xml", "/data/invoice.pdf")
                 end
          parse(out)
        end
      end

      private

      def parse(out)
        xml = out[/<\?xml.*\z/m] || out
        doc = Nokogiri::XML(xml)
        doc.remove_namespaces!
        result = doc.at_xpath("//validationReport") || doc.at_xpath("//validationResult")
        compliant = result && result["isCompliant"] == "true"
        messages = doc.xpath("//rule[@status='failed']").map do |rule|
          Message.new(level: :error, code: "#{rule["specification"]} #{rule["clause"]} test #{rule["testNumber"]}",
                      text: rule.at_xpath("./description")&.text.to_s.strip)
        end
        Report.new(tool: "veraPDF", valid: compliant, messages: messages, raw: out)
      end
    end
  end
end
