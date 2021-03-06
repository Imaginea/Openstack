class deployment::load_balancer(
  $controller_virtual_ip,
  $swift_proxy_virtual_ip,
  $controller_names,
  $controller_ipaddresses,
  $swift_proxy_names,
  $swift_proxy_ipaddresses,
  $controller_state,
  $swift_proxy_state,
  $track_script = 'haproxy',
  $keepalived_interface = 'eth0',
  $swift_enabled = false
) {

	exec{'sysctl-install':
		command => 'puppet module install thias/sysctl',
	}

	sysctl::value {'net.ipv4.ip_nonlocal_bind':
		value => '1',
		require => Exec['sysctl-install'],
		}

	exec{'sysctl':
		command => 'sysctl -p',
		require => Exec['sysctl-install'],
	}

	#file{'/var/lib/haproxy':
	#	ensure => directory,
	#	owner => root,
	#	group => root,
	#}

  include keepalived
#  include haproxy

  if ($controller_state == 'MASTER') {
    $controller_priority = '101'
  } else {
    $controller_priority = '100'
  }

  if ($swift_proxy_state == 'MASTER') {
    $swift_proxy_priority = '101'
  } else {
    $swift_proxy_priority = '100'
  }

	keepalived::vrrp_script { 'haproxy':
		name_is_process => true,
		weight =>2,   # 2 is default parameter value
		interval => 2, # 2 is default parameter value
	}


  keepalived::instance { '50':
    interface    => $keepalived_interface,
    virtual_ips  => "${controller_virtual_ip} dev ${keepalived_interface}",
    state        => $controller_state,
    priority     => $controller_priority,
    track_script => [$track_script],
	advert_int => 1, # 1 is default parameter value
  }

  keepalived::instance { '51':
    interface    => $keepalived_interface,
    virtual_ips  => "${swift_proxy_virtual_ip} dev ${keepalived_interface}",
    state        => $swift_proxy_state,
    priority     => $swift_proxy_priority,
    track_script => [$track_script],
  }

	class { 'haproxy':
    manage_service   => false,
	enable => true,
    notify           => [Exec['restart-keystone'],Exec['restart-glance'],Exec['restart-glance-reg'],Exec['restart-cinder'],Exec['restart-novnc'],Exec['stop-apache'],Service['haproxy']],
    defaults_options => {
      'log'     => 'global',
      'option'  => 'redispatch',
      'retries' => '3',
      'timeout' => [
        'http-request 10s',
        'queue 1m',
        'connect 10s',
        'client 1m',
        'server 1m',
        'check 10s',
      ],
      'maxconn' => '8000'
    }
  }

  haproxy::listen { 'galera_cluster':
    ipaddress => $controller_virtual_ip,
    ports     => '3306',
    options   => {
      'option'  => ['httpchk'],
      'mode'    => 'tcp',
      'balance' => 'source'
    }
  }

  haproxy::balancermember { 'galera':
    listening_service => 'galera_cluster',
    ports             => '3306',
    server_names      => $controller_names,
    ipaddresses       => $controller_ipaddresses,
    # Note: Checking port 9200 due to health_check script.
    options           => 'check port 9200 inter 2000 rise 2 fall 5',
  }

  haproxy::listen { 'rabbit_cluster':
    ipaddress => $controller_virtual_ip,
    ports     => '5672',
    options   => {
      'option'  => ['tcpka', 'tcplog'],
      'mode'    => 'tcp',
      'balance' => 'source'
    }
  }

  haproxy::balancermember { 'rabbit;':
    listening_service => 'rabbit_cluster',
    ports             => '5672',
    server_names      => $controller_names,
    ipaddresses       => $controller_ipaddresses,
    options           => 'check inter 2000 rise 2 fall 5',
  }

  haproxy::listen { 'keystone_public_internal_cluster':
    ipaddress => $controller_virtual_ip,
    ports     => '5000',
    options   => {
      'option'  => ['tcpka', 'httpchk', 'tcplog'],
      'balance' => 'source'
    }
  }

  haproxy::balancermember { 'keystone_public_internal':
    listening_service => 'keystone_public_internal_cluster',
    ports             => '5000',
    server_names      => $controller_names,
    ipaddresses       => $controller_ipaddresses,
    options           => 'check inter 2000 rise 2 fall 5',
  }

  haproxy::listen { 'keystone_admin_cluster':
    ipaddress => $controller_virtual_ip,
    ports     => '35357',
    options   => {
      'option'  => ['tcpka', 'httpchk', 'tcplog'],
      'balance' => 'source'
    }
  }

  haproxy::balancermember { 'keystone_admin':
    listening_service => 'keystone_admin_cluster',
    ports             => '35357',
    server_names      => $controller_names,
    ipaddresses       => $controller_ipaddresses,
    options           => 'check inter 2000 rise 2 fall 5',
  }

  haproxy::listen { 'nova_ec2_api_cluster':
    ipaddress => $controller_virtual_ip,
    ports     => '8773',
    options   => {
      'option'  => ['tcpka', 'tcplog'],
      'balance' => 'source'
    }
  }

  haproxy::balancermember { 'nova_ec2':
    listening_service => 'nova_ec2_api_cluster',
    ports             => '8773',
    server_names      => $controller_names,
    ipaddresses       => $controller_ipaddresses,
    options           => 'check inter 2000 rise 2 fall 5',
  }

  haproxy::listen { 'nova_osapi_cluster':
    ipaddress => $controller_virtual_ip,
    ports     => '8774',
    options   => {
      'option'  => ['tcpka', 'httpchk', 'tcplog'],
      'balance' => 'source'
    }
  }

  haproxy::balancermember { 'nova_osapi':
    listening_service => 'nova_osapi_cluster',
    ports             => '8774',
    server_names      => $controller_names,
    ipaddresses       => $controller_ipaddresses,
    options           => 'check inter 2000 rise 2 fall 5',
  }

  haproxy::listen { 'nova_metadata_api_cluster':
    ipaddress => $controller_virtual_ip,
    ports     => '8775',
    options   => {
      'option'  => ['tcpka', 'tcplog'],
      'balance' => 'source'
    }
  }

  haproxy::balancermember { 'nova_metadata':
    listening_service => 'nova_metadata_api_cluster',
    ports             => '8775',
    server_names      => $controller_names,
    ipaddresses       => $controller_ipaddresses,
    options           => 'check inter 2000 rise 2 fall 5',
  }

  haproxy::listen { 'neutron_api_cluster':
    ipaddress => $controller_virtual_ip,
    ports     => '9696',
    options   => {
      'option'  => ['tcpka', 'httpchk', 'tcplog'],
      'balance' => 'source'
    }
  }

  haproxy::balancermember { 'neutron_api':
    listening_service => 'neutron_api_cluster',
    ports             => '9696',
    server_names      => $controller_names,
    ipaddresses       => $controller_ipaddresses,
    options           => 'check inter 2000 rise 2 fall 5',
  }

  haproxy::listen { 'cinder_api_cluster':
    ipaddress => $controller_virtual_ip,
    ports     => '8776',
    options   => {
      'option'  => ['tcpka', 'httpchk', 'tcplog'],
      'balance' => 'source'
    }
  }

  haproxy::balancermember { 'cinder_api':
    listening_service => 'cinder_api_cluster',
    ports             => '8776',
    server_names      => $controller_names,
    ipaddresses       => $controller_ipaddresses,
    options           => 'check inter 2000 rise 2 fall 5',
  }

  haproxy::listen { 'ceilometer_api_cluster':
    ipaddress => $controller_virtual_ip,
    ports     => '8777',
    options   => {
      'option'  => ['tcpka', 'httpchk', 'tcplog'],
      'balance' => 'source'
    }
  }

  haproxy::balancermember { 'ceilometer_api':
    listening_service => 'ceilometer_api_cluster',
    ports             => '8777',
    server_names      => $controller_names,
    ipaddresses       => $controller_ipaddresses,
    options           => 'check inter 2000 rise 2 fall 5',
  }

  haproxy::listen { 'glance_registry_cluster':
    ipaddress => $controller_virtual_ip,
    ports     => '9191',
    options   => {
      'option'  => ['tcpka', 'tcplog'],
      'balance' => 'source'
    }
  }

  haproxy::balancermember { 'glance_registry':
    listening_service => 'glance_registry_cluster',
    ports             => '9191',
    server_names      => $controller_names,
    ipaddresses       => $controller_ipaddresses,
    options           => 'check inter 2000 rise 2 fall 5',
  }

  haproxy::listen { 'glance_api_cluster':
    ipaddress => $controller_virtual_ip,
    ports     => '9292',
    options   => {
      'option'  => ['tcpka', 'httpchk', 'tcplog'],
      'balance' => 'source'
    }
  }

  haproxy::balancermember { 'glance_api':
    listening_service => 'glance_api_cluster',
    ports             => '9292',
    server_names      => $controller_names,
    ipaddresses       => $controller_ipaddresses,
    options           => 'check inter 2000 rise 2 fall 5',
  }

  haproxy::listen { 'heat_api_cluster':
    ipaddress => $controller_virtual_ip,
    ports     => '8004',
    options   => {
      'option'  => ['tcpka', 'httpchk', 'tcplog'],
      'balance' => 'source'
    }
  }

  haproxy::balancermember { 'heat_api':
    listening_service => 'heat_api_cluster',
    ports             => '8004',
    server_names      => $controller_names,
    ipaddresses       => $controller_ipaddresses,
    options           => 'check inter 2000 rise 2 fall 5',
  }

  haproxy::listen { 'heat_cfn_api_cluster':
    ipaddress => $controller_virtual_ip,
    ports     => '8000',
    options   => {
      'option'  => ['tcpka', 'httpchk', 'tcplog'],
      'balance' => 'source'
    }
  }

  haproxy::balancermember { 'heat_cfn_api':
    listening_service => 'heat_api_cluster',
    ports             => '8000',
    server_names      => $controller_names,
    ipaddresses       => $controller_ipaddresses,
    options           => 'check inter 2000 rise 2 fall 5',
  }

  # Note: Failures were experienced when the balance-member was named Horizon.
  haproxy::listen { 'dashboard_cluster':
    ipaddress => $controller_virtual_ip,
    ports     => '80',
    options   => {
      'option'  => ['forwardfor', 'httpchk', 'httpclose'],
      'mode'    => 'http',
      'cookie'  => 'SERVERID insert indirect nocache',
      'capture' => 'cookie vgnvisitor= len 32',
      'balance' => 'source',
      'rspidel' => '^Set-cookie:\ IP='
    }
  }

  # Note: Failures were experienced when the balance-member was named Horizon.
  haproxy::balancermember { 'dashboard':
    listening_service => 'dashboard_cluster',
    ports             => '80',
    server_names      => $controller_names,
    ipaddresses       => $controller_ipaddresses,
    options           => 'check inter 2000 rise 2 fall 5',
    define_cookies    => true
  }

  # Uncomment if using NoVNC
  haproxy::listen { 'novnc_cluster':
    ipaddress => $controller_virtual_ip,
    ports     => '6080',
    options   => {
      'option'  => ['tcpka', 'tcplog'],
      'balance' => 'source'
    }
  }

  # Uncomment if using NoVNC
  haproxy::balancermember { 'novnc':
    listening_service => 'novnc_cluster',
    ports             => '6080',
    server_names      => $controller_names,
    ipaddresses       => $controller_ipaddresses,
    options           => 'check inter 2000 rise 2 fall 5',
  }


  haproxy::listen { 'nova_memcached_cluster':
    ipaddress => $controller_virtual_ip,
    ports     => '11211',
    options   => {
      'option'  => ['tcpka', 'tcplog'],
      'balance' => 'source'
    }
  }

  haproxy::balancermember { 'nova_memcached':
    listening_service => 'nova_memcached_cluster',
    ports             => '11211',
    server_names      => $controller_names,
    ipaddresses       => $controller_ipaddresses,
    options           => 'check inter 2000 rise 2 fall 5',
  }

  if $swift_enabled {

    haproxy::listen { 'swift_proxy_cluster':
      ipaddress => $swift_proxy_virtual_ip,
      ports     => '8080',
      options   => {
        'option'  => ['tcpka', 'tcplog'],
        'balance' => 'source'
      }
    }

    haproxy::balancermember { 'swift_proxy':
      listening_service => 'swift_proxy_cluster',
      ports             => '8080',
      server_names      => $swift_proxy_names,
      ipaddresses       => $swift_proxy_ipaddresses,
      options           => 'check inter 2000 rise 2 fall 5',
    }

    haproxy::listen { 'swift_memcached_cluster':
      ipaddress => $swift_proxy_virtual_ip,
      ports     => '11211',
      options   => {
        'option'  => ['tcpka', 'tcplog'],
        'balance' => 'source'
      }
    }

    haproxy::balancermember { 'swift_memcached':
      listening_service => 'swift_memcached_cluster',
      ports             => '11211',
      server_names      => $swift_proxy_names,
      ipaddresses       => $swift_proxy_ipaddresses,
      options           => 'check inter 2000 rise 2 fall 5',
    }

  }

  exec {'restart-keystone':
    command     => '/usr/sbin/service keystone restart',
    onlyif      => '/usr/bin/test -s /etc/init.d/keystone',
    subscribe   => File['/etc/haproxy/haproxy.cfg'],
    refreshonly => true
  }

  exec {'restart-glance':
    command     => '/usr/sbin/service glance-api restart',
    onlyif      => '/usr/bin/test -s /etc/init.d/glance-api',
    subscribe   => File['/etc/haproxy/haproxy.cfg'],
    refreshonly => true
  }

  exec {'restart-glance-reg':
    command     => '/usr/sbin/service glance-registry restart',
    onlyif      => '/usr/bin/test -s /etc/init.d/glance-registry',
    subscribe   => File['/etc/haproxy/haproxy.cfg'],
    refreshonly => true
  }

  exec {'restart-heat':
    command     => '/usr/sbin/service heat-api restart',
    onlyif      => '/usr/bin/test -s /etc/init.d/heat-api',
    subscribe   => File['/etc/haproxy/haproxy.cfg'],
    refreshonly => true
  }

  exec {'restart-cinder':
    command     => '/usr/sbin/service cinder-api restart',
    onlyif      => '/usr/bin/test -s /etc/init.d/cinder-api',
    subscribe   => File['/etc/haproxy/haproxy.cfg'],
    refreshonly => true
  }

  exec {'restart-ceilometer':
    command     => '/usr/sbin/service ceilometer-api restart',
    onlyif      => '/usr/bin/test -s /etc/init.d/ceilometer-api',
    subscribe   => File['/etc/haproxy/haproxy.cfg'],
    refreshonly => true
  }

  exec {'restart-novnc':
    command     => '/usr/sbin/service nova-novncproxy restart',
    onlyif      => '/usr/bin/test -s /etc/init.d/nova-novncproxy',
    subscribe   => File['/etc/haproxy/haproxy.cfg'],
    refreshonly => true
  }

  exec {'stop-apache':
    command     => '/usr/sbin/service apache2 stop',
    onlyif      => '/usr/bin/test -s /etc/init.d/apache2',
    subscribe   => File['/etc/haproxy/haproxy.cfg'],
    refreshonly => true
  }

  service { 'haproxy':
    ensure  => running,
	hasstatus => true,
    require => Package['haproxy']
  }


}
