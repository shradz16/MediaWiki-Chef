#
# Cookbook:: mediawiki
# Recipe:: default
#
# Copyright:: 2020, The Authors, All Rights Reserved.

#install packages- php, apache, mariadb
%w(httpd php php-mysqlnd php-gd php-xml mariadb-server mariadb php-mbstring php-json git wget).each do |package|
  package package do
    action :install
  end
end

#rhel8 comes with default php 7.2, reset module and install php 7.4 for mediawiki
bash 'Upgrade php' do
  code <<-EOH
  dnf module reset php -y
  dnf module list php
  sudo dnf module install php:7.4/common -y
  EOH
end

#start the database
service 'mariadb' do
  action :start
end

bash 'Configure mysql' do
  user 'root'
  code <<-EOH
    mysql -e "CREATE DATABASE #{node['mediawiki']['db']};"
    mysql -e "CREATE USER #{node['mediawiki']['db_user']}@localhost IDENTIFIED BY '#{node['mediawiki']['db_password']}';"
    mysql -e "GRANT ALL PRIVILEGES ON #{node['mediawiki']['db']}.* TO '#{node['mediawiki']['db_user']}'@'localhost';"
    mysql -e "FLUSH PRIVILEGES;"
  EOH
end

service 'mariadb' do
  action [ :enable, :restart ]
end

#start apache service
service 'httpd' do
  action [ :enable, :restart ]
end

#wget mediawiki package
remote_file '/var/www/' + node['mediawiki']['apps'] + '.tar.gz' do
  owner 'root'
  group 'root'
  mode '0644'
  source node['mediawiki']['link']
  not_if { ::File.exist?('/var/www/' + node['mediawiki']['apps'] + '.tar.gz') }
end

#Install mediawiki package
bash 'Install mediawiki' do
  user 'root'
  cwd '/var/www/html'
  code <<-EOH
  tar -xvzf /var/www/#{node['mediawiki']['apps']}.tar.gz -C .
  mv #{node['mediawiki']['apps']}-#{node['mediawiki']['version']} #{node['mediawiki']['apps']}
  chown -R apache:apache #{node['mediawiki']['apps']}
  chmod 755 #{node['mediawiki']['apps']}
  php #{node['mediawiki']['apps']}/maintenance/install.php --conf #{node['mediawiki']['apps']}/LocalSettings.php #{node['mediawiki']['title']} admin --pass #{node['mediawiki']['db_password']} --dbname #{node['mediawiki']['db']} --dbuser #{node['mediawiki']['db_user']} --dbpass #{node['mediawiki']['db_password']} --server http://#{node['ec2']['public_ipv4']} --lang en
  EOH
  not_if { ::File.exist?('/var/www/html/' + node['mediawiki']['apps'] + '/LocalSettings.php') }
end


#restart the service
service 'httpd' do
  action :restart
end

