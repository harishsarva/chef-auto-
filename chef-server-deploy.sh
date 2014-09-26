#!/bin/bash 

curl -L https://www.opscode.com/chef/install.sh | sudo bash || echo " curl failed "
mkdir -p /var/chef/cache /var/chef/cookbooks || echo " unable to make directories " 
rsync -avr chef-server /var/chef/cookbooks/
chef-solo -o 'recipe[chef-server::cb-setup]' || echo "chef solo failed " 
chef-solo -o 'recipe[chef-server::default]' || echo "chef solo failed " 


