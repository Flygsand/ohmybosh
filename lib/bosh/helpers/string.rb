module Bosh
  module Helpers
    module String
      def to_i(str)
        str.nil? ? nil : str.to_i
      end

      def to_bool(str)
        str.nil? ? nil : str == 'true'
      end
    end
  end
end
