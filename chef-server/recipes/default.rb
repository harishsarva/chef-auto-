#
# Copyright:: Copyright (c) 2012 Opscode, Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

require 'resolv'
require 'chef/util/file_edit'

# Acquire the chef-server Omnibus package
if node['chef-server']['package_file'].nil? || node['chef-server']['package_file'].empty?
  omnibus_package = OmnitruckClient.new(node).package_for_version(
    node['chef-server']['version'],
    node['chef-server']['prereleases'],
    node['chef-server']['nightlies']
    )
  unless omnibus_package
    err_msg = 'Could not locate chef-server'
    err_msg << ' pre-release' if node['chef-server']['prereleases']
    err_msg << ' nightly' if node['chef-server']['nightlies']
    err_msg << " package matching version '#{node['chef-server']['version']}' for node."
    fail err_msg
  end
else
  omnibus_package = node['chef-server']['package_file']
end

package_name = ::File.basename(omnibus_package)
package_local_path = "#{Chef::Config[:file_cache_path]}/#{package_name}"

# Ensure :file_cache_path exists
directory Chef::Config[:file_cache_path] do
  owner 'root'
  group 'root'
  recursive true
  action :create
end

# omnibus_package is remote (ie a URI) let's download it
if ::URI.parse(omnibus_package).absolute?
  remote_file package_local_path do
    source omnibus_package
    if node['chef-server']['package_checksum']
      checksum node['chef-server']['package_checksum']
      action :create
    else
      action :create_if_missing
    end
  end
  # else we assume it's on the local machine
else
  package_local_path = omnibus_package
end

# install the platform package
package package_name do # ignore ~FC009 known bug in food critic causes this to trigger see Foodcritic Issue #137
  source package_local_path
  provider case node['platform_family']
           when 'debian' then Chef::Provider::Package::Dpkg
           when 'rhel' then Chef::Provider::Package::Rpm
           else
             fail RuntimeError("I don't know how to install chef-server packages for platform family '#{node["platform_family"]}'!")
           end
  options node['chef-server']['package_options']
  action :install
  notifies :run, 'execute[reconfigure-chef-server]'
end

# create the chef-server etc directory
directory '/etc/chef-server' do
  owner 'root'
  group 'root'
  recursive true
  action :create
end

# create the initial chef-server config file
template '/etc/chef-server/chef-server.rb' do
  source 'chef-server.rb.erb'
  owner 'root'
  group 'root'
  action :create
  notifies :run, 'execute[reconfigure-chef-server]', :immediately
end

# reconfigure the installation
execute 'reconfigure-chef-server' do
  command 'chef-server-ctl reconfigure'
  action :nothing
end

ruby_block 'ensure node can resolve API FQDN' do
  block do
    fe = Chef::Util::FileEdit.new('/etc/hosts')
    fe.insert_line_if_no_match(/#{node['chef-server']['api_fqdn']}/,
      "127.0.0.1 #{node['chef-server']['api_fqdn']}")
    fe.write_file
  end
  not_if { Resolv.getaddress(node['chef-server']['api_fqdn']) rescue false } # host resolves
end

if not File.exists?("/root/.chef")
  directory "/root/.chef" do
    owner "root"
    group "root"
    mode "0755"
    action :create
  end
end

template '/root/.chef/knife.rb' do
  source 'master_knife.rb'
  owner "root"
  group "root"
  mode "0755"
  action :create
  variables(
    :server_url => node['chef-server']['api_fqdn'] 
  )
end 

bash "cookbooks_add" do
  user "root"
  cwd "/var/chef"
  code <<-EOH
  for i in `ls cookbooks/` ; do knife cookbook upload $i -o cookbooks/ ; done 
  for i in `ls cookbooks/` ; do knife cookbook upload $i -o cookbooks/ ; done 
  for i in `ls cookbooks1/` ; do knife cookbook upload $i -o cookbooks1/ ; done 
  for i in `ls cookbooks2/` ; do knife cookbook upload $i -o cookbooks2/ ; done 
  for i in `ls cookbooks/` ; do knife cookbook upload $i -o cookbooks/ ; done 
  for i in `ls cookbooks/` ; do knife cookbook upload $i -o cookbooks/ ; done 
  for i in `ls cookbooks/` ; do knife cookbook upload $i -o cookbooks/ ; done 
  for i in `ls cookbooks1/` ; do knife cookbook upload $i -o cookbooks1/ ; done 
  for i in `ls cookbooks2/` ; do knife cookbook upload $i -o cookbooks2/ ; done 
  EOH
  only_if " cat /root/.chef/knife.rb | grep `hostname` "  # make sure we are not still on chef02.nfs.hightail.com 
end


