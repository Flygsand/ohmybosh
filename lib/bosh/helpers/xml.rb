module Bosh
  module Helpers
    module XML
      def to_xml(obj)
        root(obj).to_xml(:save_with => Nokogiri::XML::Node::SaveOptions::AS_XML)
      end

      def from_xml(xml)
        root(Nokogiri::XML(xml))
      end

      def root(obj)
        obj = obj.doc if obj.respond_to?(:doc)
        obj = obj.root if obj.respond_to?(:root)
        obj
      end
    end
  end
end
