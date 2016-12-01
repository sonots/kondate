require 'yaml'
require 'kondate'

recipes = node['attributes'].keys
recipes.each do |recipe|
  secret_recipe_file = File.join(Kondate::Config.secret_middleware_recipes_dir, recipe, "default.rb")
  recipe_file = File.join(Kondate::Config.middleware_recipes_dir, recipe, "default.rb")
  File.exist?(secret_recipe_file) ? include_recipe(secret_recipe_file) : include_recipe(recipe_file)
end
sep = File::SEPARATOR
secret_role_recipe_file = Kondate::RoleFile.explore(Kondate::Config.secret_roles_recipes_dir, node[:role], "#{sep}default.rb")
role_recipe_file = Kondate::RoleFile.explore(Kondate::Config.roles_recipes_dir, node[:role], "#{sep}default.rb")
if File.exist?(secret_role_recipe_file)
  include_recipe(secret_role_recipe_file)
elsif File.exist?(role_recipe_file)
  include_recipe(role_recipe_file)
end
