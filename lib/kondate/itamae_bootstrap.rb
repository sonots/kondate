module Kondate
  class ItamaeBootstrap
    # @param [Itamae::Recipe::EvalContext] context itamae context
    def self.bootstrap(context)
      self.new(context).bootstrap
    end

    # @param [Itamae::Recipe::EvalContext] context itamae context
    def initialize(context)
      @context = context
    end

    def bootstrap
      bootstrap_middleware_recipes
      bootstrap_role_recipes
    end

    private

    def node
      @context.node
    end

    def include_recipe(recipe)
      @context.include_recipe(recipe)
    end

    def bootstrap_middleware_recipes
      recipes = node['attributes'].keys
      recipes.each do |recipe|
        secret_recipe_file = File.join(Config.secret_middleware_recipes_dir, recipe, "default.rb")
        recipe_file = File.join(Config.middleware_recipes_dir, recipe, "default.rb")
        File.exist?(secret_recipe_file) ? include_recipe(secret_recipe_file) : include_recipe(recipe_file)
      end
    end

    def bootstrap_role_recipes
      sep = File::SEPARATOR
      secret_role_recipe_file = RoleFile.explore(Config.secret_roles_recipes_dir, node[:role], "#{sep}default.rb")
      role_recipe_file = RoleFile.explore(Config.roles_recipes_dir, node[:role], "#{sep}default.rb")
      if File.exist?(secret_role_recipe_file)
        include_recipe(secret_role_recipe_file)
      elsif File.exist?(role_recipe_file)
        include_recipe(role_recipe_file)
      end
    end
  end
end
