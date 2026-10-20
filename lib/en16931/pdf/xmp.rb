# frozen_string_literal: true

module EN16931
  module PDF
    # The XMP packet a PDF/A-3b hybrid needs: PDF/A identification, the
    # Dublin Core and PDF entries that mirror the Info dictionary, and the
    # Factur-X/ZUGFeRD extension schema with the four document properties.
    module XMP
      FX_NS = "urn:factur-x:pdfa:CrossIndustryDocument:invoice:1p0#"

      module_function

      def build(title:, author:, created_at:, producer:, creator_tool:, filename:, conformance:, document_type: "INVOICE")
        stamp = created_at.utc.strftime("%Y-%m-%dT%H:%M:%SZ")
        <<~XMP
          <?xpacket begin="﻿" id="W5M0MpCehiHzreSzNTczkc9d"?>
          <x:xmpmeta xmlns:x="adobe:ns:meta/">
            <rdf:RDF xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#">
              <rdf:Description rdf:about="" xmlns:pdfaid="http://www.aiim.org/pdfa/ns/id/">
                <pdfaid:part>3</pdfaid:part>
                <pdfaid:conformance>B</pdfaid:conformance>
              </rdf:Description>
              <rdf:Description rdf:about="" xmlns:dc="http://purl.org/dc/elements/1.1/">
                <dc:title><rdf:Alt><rdf:li xml:lang="x-default">#{escape(title)}</rdf:li></rdf:Alt></dc:title>
                <dc:creator><rdf:Seq><rdf:li>#{escape(author)}</rdf:li></rdf:Seq></dc:creator>
              </rdf:Description>
              <rdf:Description rdf:about="" xmlns:xmp="http://ns.adobe.com/xap/1.0/">
                <xmp:CreatorTool>#{escape(creator_tool)}</xmp:CreatorTool>
                <xmp:CreateDate>#{stamp}</xmp:CreateDate>
                <xmp:ModifyDate>#{stamp}</xmp:ModifyDate>
              </rdf:Description>
              <rdf:Description rdf:about="" xmlns:pdf="http://ns.adobe.com/pdf/1.3/">
                <pdf:Producer>#{escape(producer)}</pdf:Producer>
              </rdf:Description>
              <rdf:Description rdf:about=""
                  xmlns:pdfaExtension="http://www.aiim.org/pdfa/ns/extension/"
                  xmlns:pdfaSchema="http://www.aiim.org/pdfa/ns/schema#"
                  xmlns:pdfaProperty="http://www.aiim.org/pdfa/ns/property#">
                <pdfaExtension:schemas>
                  <rdf:Bag>
                    <rdf:li rdf:parseType="Resource">
                      <pdfaSchema:schema>Factur-X PDFA Extension Schema</pdfaSchema:schema>
                      <pdfaSchema:namespaceURI>#{FX_NS}</pdfaSchema:namespaceURI>
                      <pdfaSchema:prefix>fx</pdfaSchema:prefix>
                      <pdfaSchema:property>
                        <rdf:Seq>
                          #{property("DocumentFileName", "name of the embedded XML invoice file")}
                          #{property("DocumentType", "INVOICE")}
                          #{property("Version", "The actual version of the Factur-X XML schema")}
                          #{property("ConformanceLevel", "The conformance level of the embedded Factur-X data")}
                        </rdf:Seq>
                      </pdfaSchema:property>
                    </rdf:li>
                  </rdf:Bag>
                </pdfaExtension:schemas>
              </rdf:Description>
              <rdf:Description rdf:about="" xmlns:fx="#{FX_NS}">
                <fx:DocumentType>#{document_type}</fx:DocumentType>
                <fx:DocumentFileName>#{filename}</fx:DocumentFileName>
                <fx:Version>1.0</fx:Version>
                <fx:ConformanceLevel>#{conformance}</fx:ConformanceLevel>
              </rdf:Description>
            </rdf:RDF>
          </x:xmpmeta>
          <?xpacket end="w"?>
        XMP
      end

      def property(name, description)
        <<~PROP.strip
          <rdf:li rdf:parseType="Resource">
            <pdfaProperty:name>#{name}</pdfaProperty:name>
            <pdfaProperty:valueType>Text</pdfaProperty:valueType>
            <pdfaProperty:category>external</pdfaProperty:category>
            <pdfaProperty:description>#{description}</pdfaProperty:description>
          </rdf:li>
        PROP
      end

      def escape(text)
        text.to_s.gsub("&", "&amp;").gsub("<", "&lt;").gsub(">", "&gt;")
      end
    end
  end
end
