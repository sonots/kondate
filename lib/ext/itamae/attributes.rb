# top level at recipe
module Itamae
  class Recipe
    class EvalContext
      def attrs
        node[:attributes]
      end
    end
  end
end

# resource { here }
module Itamae
  module Resource
    class Base
      class EvalContext
        def attrs
          node[:attributes]
        end
      end
    end
  end
end

# templates
module Itamae
  module Resource
    class Template < RemoteFile
      class RenderContext
        def attrs
          node[:attributes]
        end
      end
    end
  end
end
