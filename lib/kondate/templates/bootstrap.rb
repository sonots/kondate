require 'yaml'
require 'kondate'

recipes = node['attributes'].keys
recipes.each do |recipe|
  include_recipe(File.join(Kondate::Config.middleware_recipes_dir, recipe, "default.rb"))
end
role_recipe = Kondate::RoleFile.explore(Kondate::Config.roles_recipes_dir, node[:role], "#{File::SEPARATOR}default.rb")
if File.exist?(role_recipe)
  include_recipe(role_recipe)
end
