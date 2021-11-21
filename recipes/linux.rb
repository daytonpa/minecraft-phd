#
# Cookbook:: minecraft-phd
# Recipe:: linux
#
# Copyright:: 2021, The Authors, All Rights Reserved.

# update and schedule updates
apt_update 'update' do
  frequency 43200
  action :periodic
  notifies :run, 'execute[apt upgrade]', :immediately
end

execute 'apt upgrade' do
  command 'apt upgrade -y'
  action :nothing
end

cron 'apt upgrade schedule' do
  minute '0'
  hour '0'
  day '*'
  command 'sudo apt upgrade -y'
end

# minecraft system user and group
user node['minecraft']['user'] do
  home node['minecraft']['user_home']
  comment node['minecraft']['user_desc']
  shell node['minecraft']['shell']
  system node['minecraft']['system_account']
  uid node['minecraft']['uid']
end

group node['minecraft']['group'] do
  comment node['minecraft']['group_desc']
  gid node['minecraft']['gid']
  members %W(#{node['minecraft']['user']})
  system node['minecraft']['system_account']
end

# installation and mount directory
directory '/opt/minercraft' do
  owner node['minecraft']['user']
  group node['minecraft']['group']
  mode '0755'
end

# format and mount the data disk
execute 'format minecraft data disk' do
  command <<-COMMAND
    mkfs -t xfs /dev/nvme1n1
  COMMAND
  not_if 'blkid /dev/nvme1n1 | grep \'\xfs\''
end

mount 'minecraft data disk' do
  device '/dev/nvme1n1'
  device_type 'xfs'
  mount_point '/opt/minecraft'
  action %i(mount enable)
end

# package dependencies
apt_package %w(
  software-properties-common
  python-properties-common
  vim 
  telnet
  wget
  screen
  openjdk-16-jdk-headless
)

# install the aws-cli
execute 'download aws-cli zip for installation' do
  pwd Chef::Config[:file_cache_path]
  command <<-COMMAND
  curl 'https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip' \
    -o 'awscliv2.zip'
  COMMAND
  not_if { ::File.exist?("#{Chef::Config[:file_cache_path]}/awscliv2.zip") }
  notifies :run, 'bash[unzip and install aws-cli]', :immediately
end

bash 'unzip and install aws-cli' do
  cwd Chef::Config[:file_cache_path]
  code <<-CODE
    unzip awscliv2.zip
    sudo ./aws/install
  CODE
  action :nothing
end

# create directories for the minecraft daemon
%w(
  /opt/minecraft/jars
  /opt/minecraft/etc
  /opt/minecraft/run
  /opt/minecraft/log
).each do |dir|
  directory dir do
    owner node['minecraft']['user']
    group node['minecraft']['group']
    mode '0755'
  end
end

bash 'download server.jar from S3' do
  code <<-CODE
    aws s3 cp s3://bearclaw-minecraft-us-east-1/minecraft/jars/server.jar \
      /opt/minecraft/jars/server.jar
    chown -Rf minecraft:minecraft /opt/minecraft/jars/server.jar
  CODE
  not_if 'ls -al /opt/minecraft/jars/server.jar | grep -q \'minecraft minecraft\''
end

template 'minecraft runtime environment config' do
  owner node['minecraft']['user']
  group node['minecraft']['group']
  path '/opt/minecraft/etc/minecraft.env'
  source 'config/minecraft.env.erb'
end

template 'minecraft systemd file' do
  owner node['minecraft']['user']
  group node['minecraft']['group']
  path '/etc/systemd/system/minecraft-server.service'
  source 'config/minecraft.service.erb'
  
  notifies :run, 'execute[reload systemd]', :immediately
  notifies :restart, 'service[minecraft-server]', :delayed
end

template 'minecraft logging configuration file' do
  owner node['minecraft']['user']
  group node['minecraft']['group']
  path '/opt/minecraft/etc/log4j.xml'
  source 'config/log4j.xml.erb'

  notifies :restart, 'service[minecraft-server]', :delayed
end

execute 'reload systemd' do
  command 'systemctl daemon-reload'
  action :nothing
end

service 'haproxy' do
  supports restart: true, status: true
  action %i(start enable)
end 

service 'minecraft-server' do
  supports restart: true, status: true
  action %i(start enable)
end