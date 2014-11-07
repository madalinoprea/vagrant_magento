# Default attributes.
default['vagrant_magento']['mage']['install_dir'] = "/vagrant"            # Where to install magento
default['vagrant_magento']['mage']['dir'] = "#{default['vagrant_magento']['mage']['install_dir']}/magento"             # magento base dir

default['vagrant_magento']['phpinfo_enabled'] = false                      #add an alias for a /phpinfo.php file
default['vagrant_magento']['mage_check_enabled'] = false                   #add an alias for a /magento-check.php file
default['vagrant_magento']['mage_dev_enabled'] = false                     # Enables Magento Developer mode (errors on)

default['vagrant_magento']['source']['install'] = true
default['vagrant_magento']['source']['url'] = "http://magentoversions.appspot.com"  # Default Magento versions repo used
default['vagrant_magento']['source']['type'] = "tar.bz2"                   # Extension used by Magento versions. Possible values are tar.bz2, tar.gz
default['vagrant_magento']['source']['version'] = "magento-1.7.0.2"

default['vagrant_magento']['sample_data']['install'] = false               #install Magento sample data
default['vagrant_magento']['sample_data']['url'] = "http://www.magentocommerce.com/downloads/assets"  # Default url used to download sample data
default['vagrant_magento']['sample_data']['type'] = "tar.bz2"                   # Extension used by Magento versions. Possible values are tar.bz2, tar.gz, tgz
default['vagrant_magento']['sample_data']['version'] = '1.6.1.0'           # Default Magento sample data version

# TODO: Add support for reindex, clear cache
default['vagrant_magento']['reindex'] = false                              #reindex Magento once deployed
default['vagrant_magento']['clearcache'] = false                           #clear Magento cache once deployed

default['vagrant_magento']['config']['install'] = false                    #install magento database via magento install
default['vagrant_magento']['config']['locale'] = "en_US"                   #required, Time Zone
default['vagrant_magento']['config']['timezone'] = "America/Los_Angeles"   #required, Time Zone
default['vagrant_magento']['config']['default_currency'] = "USD"           #required, Default Currency

default['vagrant_magento']['config']['db_host'] = "localhost"              #required, You can specify server port, ex.: localhost:3306
                                                                           #If you are not using default UNIX socket, you can specify it
                                                                           #here instead of host, ex.: /var/run/mysqld/mysqld.sock
                                                                           
default['vagrant_magento']['config']['db_model'] = "mysql4"                #Database type (mysql4 by default)
default['vagrant_magento']['config']['db_name'] = "magento"                #required, Database Name
default['vagrant_magento']['config']['db_user'] = "root"                   #required, Database User Name
default['vagrant_magento']['config']['db_pass'] = "root"                   #required, Database User Password
default['vagrant_magento']['config']['db_prefix'] = ""                     #optional, Database Tables Prefix
                                                                           #No table prefix will be used if not specified
                                                                           
default['vagrant_magento']['config']['session_save'] = "files"             #optional, where to store session data - in db or files. files by default
default['vagrant_magento']['config']['admin_frontname'] = ""               #optional, admin panel path, "admin" by default
default['vagrant_magento']['config']['url'] = "magento.dev"               #required, URL the store is supposed to be available at
default['vagrant_magento']['config']['skip_url_validation'] = "yes"        #optional, skip validating base url during installation or not. No by default
default['vagrant_magento']['config']['use_rewrites'] = "yes"               #optional, Use Web Server (Apache) Rewrites,
                                                                           #You could enable this option to use web server rewrites functionality for improved SEO
                                                                           #Please make sure that mod_rewrite is enabled in Apache configuration
                                                                           
default['vagrant_magento']['config']['use_secure'] = "no"                  #optional, Use Secure URLs (SSL). Enable this option only if you have SSL available.
default['vagrant_magento']['config']['secure_base_url'] = "{{base_url}}"   #optional, Secure Base URL
                                                                           #Provide a complete base URL for SSL connection.
                                                                           #For example: https://www.mydomain.com/magento/
                                                                           
default['vagrant_magento']['config']['use_secure_admin'] = "no"            #optional, Run admin interface with SSL
default['vagrant_magento']['config']['enable_charts'] = ""                 #optional, Enables Charts on the backend's dashboard

default['vagrant_magento']['config']['encryption_key'] = ""                #optional, will be automatically generated and displayed on success, if not specified

default['vagrant_magento']['config']['admin_username'] = "admin"      #required, admin user login
default['vagrant_magento']['config']['admin_password'] = "m123123"         #required, admin user password
default['vagrant_magento']['config']['admin_email'] = "test@example.com"   #required, admin user email
default['vagrant_magento']['config']['admin_firstname'] = "Admin"          #required, admin user first name
default['vagrant_magento']['config']['admin_lastname'] = "User"            #required, admin user last name

# Magento extensions
default['vagrant_magento']['modman']['url'] = "https://raw.github.com/colinmollenhour/modman/master/modman"
default['vagrant_magento']['debug']['enabled'] = false
default['vagrant_magento']['debug']['repository'] = "https://github.com/madalinoprea/magneto-debug.git"

# Awesome tool for Magento
default['vagrant_magento']['n98-magerun']['enabled'] = true
default['vagrant_magento']['n98-magerun']['repository'] = "https://raw.github.com/netz98/n98-magerun/master/n98-magerun.phar"


#override attributes for our included recipes
override['build_essential']['compiletime'] = true
override['mysql']['server_root_password'] = node['vagrant_magento']['config']['db_pass']
override['mysql']['allow_remote_root'] = true
override['mysql']['tunable']['key_buffer'] = "64M"
override['mysql']['tunable']['innodb_buffer_pool_size'] = "32M"

override['mysql']['server_root_password'] = node['vagrant_magento']['config']['db_pass']

node['mysql']['server_repl_password'] = "root"
node['mysql']['server_debian_password'] = "root"
