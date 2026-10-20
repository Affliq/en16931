# frozen_string_literal: true

module EN16931
  module Validation
    Message = Data.define(:level, :code, :text)

    # The outcome of one validator run.
    Report = Data.define(:tool, :valid, :messages, :raw) do
      def valid? = valid
      def errors = messages.select { |m| m.level == :error }
      def warnings = messages.select { |m| m.level == :warning }

      def to_s
        lines = ["#{tool}: #{valid? ? "valid" : "INVALID"}"]
        messages.each { |m| lines << "  [#{m.level}] #{m.code}: #{m.text}" }
        lines.join("\n")
      end
    end
  end
end
