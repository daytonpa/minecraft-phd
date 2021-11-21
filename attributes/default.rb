default['minecraft']['user'] = 'minecraft'
default['minecraft']['group'] = 'minecraft'
default['minecraft']['system_account'] = true
default['minecraft']['shell'] = '/bin/bash'
default['minecraft']['uid'] = '666'
default['minecraft']['user_desc'] = 'minecraft system user'
default['minecraft']['user_home'] = '/home/minecraft'
default['minecraft']['gid'] = '666'
default['minecraft']['group_desc'] = 'minecraft system group'

default['minecraft']['server_options'].tap do |sopts|
  sopts['pvp'] = true
  sopts['query.port'] = '25565'
end