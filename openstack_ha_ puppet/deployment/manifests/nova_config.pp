class deployment::nova_config($ipaddress){

	$controller_virtual_ip = $::controller_virtual_ip

	class { 'openstack::nova::controller':
		public_address     => $ipaddress,
		db_host            => $controller_virtual_ip,
		nova_db_user       => $::nova_db_user,
		nova_db_password   => $::nova_db_password,

		rabbit_password    => $::rabbit_password,
		rabbit_user        => $::rabbit_userid,
	
		nova_user_password => $::keystone_user_password,
		nova_db_dbname     => $::nova_db_dbname,
		rabbit_hosts       => $::rabbit_hosts,
		glance_api_servers => "${controller_virtual_ip}:9292",
		memcached_servers  => $::memcached_servers,
		neutron            => true,
		neutron_user_password => $::keystone_user_password,
		api_bind_address   => $ipaddress,
		sql_idle_timeout   => $sql_idle_timeout,
		private_interface  => $::private_interface,
		public_interface   => $::public_interface,
		
		#auth_host
		keystone_host      => $controller_virtual_ip,
		rabbit_cluster_nodes => $::controller_names,
		metadata_shared_secret => true,
	 }


	class {'deployment::cinder_config':
		ipaddress => $ipaddress,
		}
}
