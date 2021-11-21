#
# Cookbook:: minecraft-phd
# Recipe:: default
#
# Copyright:: 2021, The Authors, All Rights Reserved.

include_recipe 'minecraft-phd::linux' if node['platform'] =~ /(ubuntu)/
