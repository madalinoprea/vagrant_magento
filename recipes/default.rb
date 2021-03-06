include_recipe "apt"
include_recipe "build-essential"
include_recipe "git"
include_recipe "mysql::server"
include_recipe "mysql::ruby"
include_recipe "php"
include_recipe "php::module_mysql"
include_recipe "php::module_gd"
include_recipe "php::module_curl"
include_recipe "apache2"
include_recipe "apache2::mod_php5"

class Chef::Resource
  include MageHelper
end

#install apt packages
%w{unzip libsqlite3-dev php5-mcrypt php-apc php5-xdebug}.each do |pkg|
  package pkg do
    action :upgrade
  end
end

#add mod_rewrite
apache_module "rewrite" do
  enable true
end

#disable default virtualhost.
apache_site "default" do
  enable false
  
  notifies :restart, "service[apache2]"
end

#create a virtualhost that's mapped to our shared folder and hostname.
web_app "magento_dev" do
  server_name node['hostname']
  server_aliases node['fqdn'], node['host_name']
  docroot node['vagrant_magento']['mage']['dir']
  
  notifies :restart, "service[apache2]", :immediately
end

template "/etc/php5/conf.d/xdebug.ini" do
  source "xdebug.ini.erb"
  owner "root"
  group "root"
  mode 0644
end

#create a phpinfo file for use in our Apache vhost
template "/var/www/phpinfo.php" do
  mode "0644"
  source "phpinfo.php.erb"
  backup false
  
  not_if { node['vagrant_magento']['phpinfo_enabled'] == false }
  notifies :restart, "service[apache2]", :immediately
end

#get magento check system requirements script
remote_file "#{Chef::Config[:file_cache_path]}/magento-check.zip" do
  source "http://www.magentocommerce.com/_media/magento-check.zip"
  backup false
  mode "0644"
  checksum "bb61351788759da0c852ec50d703634f49c0076978ddf0b2d3dc2bc3f012666a"
  
  not_if { node['vagrant_magento']['mage_check_enabled'] == false }
end

#extract magento check
execute "magento-check-extract" do
  cwd Chef::Config[:file_cache_path]
  command "unzip -o #{Chef::Config[:file_cache_path]}/magento-check.zip -d /var/www"
  
  not_if { node['vagrant_magento']['mage_check_enabled'] == false }
  action :run
end

#create a mysql database
mysql_database node['vagrant_magento']['config']['db_name'] do
  Chef::Log::info("MySQL database #{node['vagrant_magento']['config']['db_name']} created.")
  connection ({:host => "localhost", :username => 'root', :password => node['mysql']['server_root_password']})
  action :create
end

# Download Magento source code
src_type = node['vagrant_magento']['source']['type']
magento_src_filename = "#{node['vagrant_magento']['source']['version']}.#{src_type}"
magento_src_filepath = "#{Chef::Config['file_cache_path']}/#{magento_src_filename}"
magento_src_url = "#{node['vagrant_magento']['source']['url']}/#{magento_src_filename}"

data_type = node['vagrant_magento']['sample_data']['type']
magento_data_version = node['vagrant_magento']['sample_data']['version']
magento_data_filename = "magento-sample-data-#{magento_data_version}.#{data_type}"
magento_data_filepath = "#{Chef::Config['file_cache_path']}/#{magento_data_filename}"
magento_data_dir = "#{Chef::Config['file_cache_path']}/magento-sample-data-#{magento_data_version}"
magento_data_url = "#{node['vagrant_magento']['sample_data']['url']}/#{magento_data_version}/#{magento_data_filename}"

remote_file magento_src_filepath do
  Chef::Log::info("Downloading #{magento_src_url} to #{magento_src_filepath} ... ")

  source magento_src_url
  action :create_if_missing
  backup false
  mode "0644"

  not_if { node['vagrant_magento']['source']['install'] == false }
end

# Extract Magento source code
execute "magento-extract" do
  Chef::Log::info("Extracting Magento #{magento_src_filepath} to #{node['vagrant_magento']['mage']['dir']} ... ")

  command "tar xjf #{magento_src_filepath} -C #{node['vagrant_magento']['mage']['install_dir']}"

  not_if { node['vagrant_magento']['source']['install'] == false }
  not_if { File.file?("#{node['vagrant_magento']['mage']['dir']}/index.php")}
  only_if { File.file?("#{magento_src_filepath}") }

  subscribes :run, 'execute[remote_file #{magento_src_filepath}]', :immediately
end


# Magento Sample Data
remote_file magento_data_filepath do
  Chef::Log::info("Downloading Magento sample data from #{magento_data_url} to #{magento_data_filepath} ... ")

  source magento_data_url
  action :create_if_missing
  backup false
  mode "0644"

  subscribes :create_if_missing, 'execute[magento-extract]', :immediately
  not_if { node['vagrant_magento']['sample_data']['install'] == false }
end

# Responsible to extract Magento sample data
execute "magento-data-extract" do
  Chef::Log::info("Extracting Magento sample data ...")
  cwd Chef::Config[:file_cache_path]
  command "tar xjf #{magento_data_filepath}"

  subscribes :run, 'execute[remote_file #{magento_data_filepath}]', :immediately
  not_if { node['vagrant_magento']['sample_data']['install'] == false }
  only_if { File.file?(magento_data_filepath) }
end

execute "magento-data-media-import" do
  Chef::Log::info("Importing Magento sample media ... ")
  command "cp -r #{magento_data_dir}/media #{node['vagrant_magento']['mage']['dir']}"

  subscribes :run, 'execute[magento-data-extract]', :immediately
  not_if { node['vagrant_magento']['sample_data']['install'] == false }
  not_if { File.directory?("#{node['vagrant_magento']['mage']['dir']}/media/catalog/category/apparel.jpg")}
end

# Reimport mysql if local.xml is missing and if sample_data install was requested
execute "magento-data-sql-import" do
  Chef::Log::info("Importing Magento sample data ... ")
  command "mysql -u root -p#{node['mysql']['server_root_password']} #{node['vagrant_magento']['config']['db_name']} < #{magento_data_dir}/magento_sample_data_for_#{magento_data_version}.sql"

  not_if { File.file?("#{node['vagrant_magento']['mage']['dir']}/app/etc/local.xml") }
  not_if { node['vagrant_magento']['sample_data']['install'] == false }
  subscribes :run, 'execute[magento-data-extract]', :immediately
end

# Install Magento if local.xml is missing
execute "magento-install" do
  Chef::Log::info("Installing Magento ... ")

  args = [
      "--license_agreement_accepted yes",
      "--locale #{node['vagrant_magento']['config']['locale']}",
      "--timezone #{node['vagrant_magento']['config']['timezone']}",
      "--default_currency #{node['vagrant_magento']['config']['default_currency']}",
      "--db_host #{node['vagrant_magento']['config']['db_host']}",
      "--db_model #{node['vagrant_magento']['config']['db_model']}",
      "--db_name #{node['vagrant_magento']['config']['db_name']}",
      "--db_user #{node['vagrant_magento']['config']['db_user']}",
      "--db_pass #{node['vagrant_magento']['config']['db_pass']}",
      "--url http://#{node['vagrant_magento']['config']['url']}/",
      "--admin_lastname #{node['vagrant_magento']['config']['admin_lastname']}",
      "--admin_firstname #{node['vagrant_magento']['config']['admin_firstname']}",
      "--admin_email #{node['vagrant_magento']['config']['admin_email']}",
      "--admin_username #{node['vagrant_magento']['config']['admin_username']}",
      "--admin_password #{node['vagrant_magento']['config']['admin_password']}",
  ]

  args << "--db_prefix #{node['vagrant_magento']['config']['db_prefix']}" unless node['vagrant_magento']['config']['db_prefix'].empty?
  args << "--session_save #{node['vagrant_magento']['config']['session_save']}" unless node['vagrant_magento']['config']['session_save'].empty?
  args << "--admin_frontname #{node['vagrant_magento']['config']['admin_frontname']}" unless node['vagrant_magento']['config']['admin_frontname'].empty?
  args << "--skip_url_validation #{node['vagrant_magento']['config']['skip_url_validation']}" unless node['vagrant_magento']['config']['skip_url_validation'].empty?
  args << "--use_rewrites #{node['vagrant_magento']['config']['use_rewrites']}" unless node['vagrant_magento']['config']['use_rewrites'].empty?
  args << "--use_secure #{node['vagrant_magento']['config']['use_secure']}" unless node['vagrant_magento']['config']['use_secure'].empty?
  args << "--secure_base_url #{node['vagrant_magento']['config']['secure_base_url']}" unless node['vagrant_magento']['config']['secure_base_url'].empty?
  args << "--use_secure_admin #{node['vagrant_magento']['config']['use_secure_admin']}" unless node['vagrant_magento']['config']['use_secure_admin'].empty?
  args << "--enable_charts #{node['vagrant_magento']['config']['enable_charts']}" unless node['vagrant_magento']['config']['enable_charts'].empty?
  args << "--encryption_key #{node['vagrant_magento']['config']['encryption_key']}" unless node['vagrant_magento']['config']['encryption_key'].empty?

  cwd node['vagrant_magento']['mage']['dir']
  command "rm -rf #{node['vagrant_magento']['mage']['dir']}/var/cache"
  command "php -f install.php -- #{args.join(' ')}"

  subscribes :run, 'execute[magento-data-sql-import]', :immediately
  notifies :run, 'execute[magento-clear-cache]', :delayed

  not_if { File.exists?("#{node['vagrant_magento']['mage']['dir']}/app/etc/local.xml") }
  not_if { node['vagrant_magento']['config']['install'] == false }
end


# Modman & modman based extensions
modman_base_dir = "#{node['vagrant_magento']['mage']['dir']}/.modman"
Chef::Log::info("Modman dir #{modman_base_dir}")

remote_file "/usr/bin/modman" do
  source node['vagrant_magento']['modman']['url']
  mode "0655"
  action :create_if_missing

  only_if { install_modman? }
end

execute "magento-modman-init" do
  cwd node['vagrant_magento']['mage']['dir']
  command "modman init"

  subscribes :run, 'execute[remote_file /usr/bin/modman]', :immediately
  not_if { File.directory?(modman_base_dir) }
end

execute "magento-debug-install" do
  cwd node['vagrant_magento']['mage']['dir']
  command "modman clone magneto-debug #{node['vagrant_magento']['debug']['repository']}"

  subscribes :run, 'execute[magento-modman-init]'
  notifies :run, 'execute[magento-enable-template-symlink]', :delayed
  only_if { node['vagrant_magento']['debug']['enabled'] }
  not_if { File.directory?("#{modman_base_dir}/magneto-debug")}
end

execute "magento-enable-template-symlink" do
  action :nothing

  # Set dev/template/allow_symlink to 1 to allow symlinks (works only for Magento 1.6+)
  template_symlink_query = "INSERT IGNORE INTO core_config_data (path, value) VALUES ('dev/template/allow_symlink', '1');"
  command "mysql -u root -p#{node['mysql']['server_root_password']} #{node['vagrant_magento']['config']['db_name']} -e \"#{template_symlink_query}\""

  notifies :run, 'execute[magento-clear-cache]', :delayed
end

execute "magento-clear-cache" do
  action :nothing

  # TODO: add smarter cache flushing based on magento backend cache
  command "rm -rf #{node['vagrant_magento']['mage']['dir']}/var/cache"
end

  remote_file "/usr/local/bin/n98-magerun.phar" do
  source node['vagrant_magento']['n98-magerun']['repository']
  mode "0655"
  action :create_if_missing

  not_if { node['vagrant_magento']['n98-magerun']['enabled'] == false }
end