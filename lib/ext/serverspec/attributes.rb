module Specinfra
  module Helper
    module Properties
      def attrs
        property['attributes']
      end
      def global_attrs
        property['global_attributes']
      end
    end
  end
end
