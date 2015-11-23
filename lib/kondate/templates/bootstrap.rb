require 'yaml'
require 'kondate'

recipes = node['attributes'].keys
recipes.each do |recipe|
  include_recipe(File.join(Kondate::Config.middleware_recipes_dir, recipe, "default.rb"))
end
if File.exist?(File.join(Kondate::Config.roles_recipes_dir, node[:role], "default.rb"))
  include_recipe(File.join(Kondate::Config.roles_recipes_dir, node[:role], "default.rb"))
end
