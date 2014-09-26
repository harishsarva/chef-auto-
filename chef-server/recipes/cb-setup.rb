
if not File.exists?("/root/.chef")
  directory "/root/.chef" do
    owner "root"
    group "root"
    mode "0755"
    action :create
  end
end

cookbook_file "/root/.chef/admin.pem" do
  source "admin.pem"
  mode "0644"
end

cookbook_file "/root/.chef/validator.pem" do
  source "validator.pem"
  mode "0644"
end

template "/root/.chef/knife.rb" do
  source "knife.rb"
  variables(
    :server_url => node["chef-server"]["url"]
  )
end

package "ntp"

bash "ntp_update" do 
  user "root"
  code <<-EOH 
   ntpdate 10.179.94.1
  EOH
end 


bash "cookbook_download" do
  user "root" 
  cwd "/var/chef/cookbooks/" 
  code <<-EOH
    for i in `knife cookbook list | awk '{print $1}' ` ; do knife cookbook download  $i -N  ; done 
    for i in `ls | grep -v chef-server`; do mv $i ` echo $i |  sed s/\-[0-9].*//g`  ; done 
  EOH
  not_if {File.exists?("/var/chef/cookbooks/ark")}
end

if not File.exists?("/var/chef/cookbooks1")
  directory "/var/chef/cookbooks1/" do
    owner "root"
    group "root"
    mode "0755"
    action :create
  end
end


if not File.exists?("/var/chef/cookbooks2")
  directory "/var/chef/cookbooks2/" do
    owner "root"
    group "root"
    mode "0755"
    action :create
  end
end


bash "cookbook_versions" do
  user "root" 
  cwd "/var/chef/cookbooks1/" 
  code <<-EOH
    rm -fr * 
    knife cookbook download logrotate 1.5.0
    knife cookbook download ark  0.4.2 
    knife cookbook download build-essential  1.4.4
    knife cookbook download openssl 1.1.0
    knife cookbook download tram 1.0.0
    knife cookbook download cassandra 2.4.0
    knife cookbook download yum 3.0.6
    knife cookbook download ht-yum  0.2.5
    for i in `ls` ; do mv $i ` echo $i |  sed s/\-[0-9].*//g`  ; done 
  EOH
end




bash "cookbook_versions1" do
  user "root" 
  cwd "/var/chef/cookbooks2/" 
  code <<-EOH
    rm -fr * 
    knife cookbook download ark  0.8.2 
    knife cookbook download cassandra 2.1.0
    for i in `ls` ; do mv $i ` echo $i |  sed s/\-[0-9].*//g`  ; done 
  EOH
end

