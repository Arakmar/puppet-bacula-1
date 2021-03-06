# Class: bacula::director
#
# This class installs and configures the Bacula Backup Director
#
# Parameters:
# * db_user: the database user
# * db_pw: the database user's password
# * db_name: the database name
# * password: password to connect to the director
#
# Sample Usage:
#
#   class { 'bacula::director':
#     storage => 'mystorage.example.com'
#   }
#
class bacula::director (
  $port                = '9101',
  $listen_address      = $::ipaddress,
  $db_user             = $bacula::params::bacula_user,
  $db_pw               = 'notverysecret',
  $db_name             = $bacula::params::bacula_user,
  $db_type             = $bacula::params::db_type,
  $password            = 'secret',
  $max_concurrent_jobs = '20',
  $packages            = $bacula::params::bacula_director_packages,
  $services            = $bacula::params::bacula_director_services,
  $homedir             = $bacula::params::homedir,
  $rundir              = $bacula::params::rundir,
  $conf_dir            = $bacula::params::conf_dir,
  $director            = $::fqdn, # director here is not params::director
  $director_address    = $bacula::params::director_address,
  $storage             = $bacula::params::storage,
  $group               = $bacula::params::bacula_group,
  $job_tag             = $bacula::params::job_tag,
  $manage_client       = true,
  $messages            = {},
  $fd_connect_timeout  = undef,
  $sd_connect_timeout  = undef,
  $heartbeat_interval  = undef,
) inherits bacula::params {

  include bacula::common
  include bacula::director::defaults

  if ($manage_client) {
    include bacula::client
  }

  ensure_packages($packages, {'tag' => 'bareos'})
  ensure_packages(["bareos-database-${db_type}"], {'tag' => 'bareos'})

  service { $services:
    ensure    => running,
    enable    => true,
    subscribe => File[$bacula::ssl::ssl_files],
    require   => Package[$packages],
  }

  file { "${conf_dir}/conf.d":
    ensure => directory,
    purge => true,
    recurse => true,
    force => true,
  }

  file { "${conf_dir}/bconsole.conf":
    owner     => 'root',
    group     => $group,
    mode      => '0640',
    show_diff => false,
    content   => template('bacula/bconsole.conf.erb');
  }

  Concat {
    owner  => 'root',
    group  => $group,
    mode   => '0640',
    notify => Service[$services],
  }

  concat::fragment { 'bacula-director-header':
    order   => '00',
    target  => "${conf_dir}/bareos-dir.conf",
    content => template('bacula/bacula-dir-header.erb')
  }

  concat::fragment { 'bacula-director-tail':
    order   => '99999',
    target  => "${conf_dir}/bareos-dir.conf",
    content => template('bacula/bacula-dir-tail.erb')
  }

  create_resources(bacula::messages, $messages)

  Bacula::Director::Storage <<| tag == "bacula-${director}" |>> { conf_dir => $conf_dir }
  Bacula::Director::Client <<| tag == "bacula-${director}" |>> { conf_dir => $conf_dir }

  if !empty($job_tag) {
    Bacula::Fileset <<| tag == $job_tag |>> { conf_dir => $conf_dir }
    Bacula::Director::Job <<| tag == $job_tag |>> { conf_dir => $conf_dir }
  } else {
    Bacula::Fileset <<||>> { conf_dir => $conf_dir }
    Bacula::Director::Job <<||>> { conf_dir => $conf_dir }
  }


  Concat::Fragment <<| tag == "bacula-${director}" |>>

  concat { "${conf_dir}/bareos-dir.conf":
    show_diff => true,
  }

  $sub_confs = [
    "${conf_dir}/conf.d/schedule.conf",
    "${conf_dir}/conf.d/pools.conf",
    "${conf_dir}/conf.d/job.conf",
    "${conf_dir}/conf.d/jobdefs.conf",
    "${conf_dir}/conf.d/fileset.conf",
    "${conf_dir}/conf.d/profile.conf",
  ]

  $sub_confs_with_secrets = [
    "${conf_dir}/conf.d/client.conf",
    "${conf_dir}/conf.d/storage.conf",
    "${conf_dir}/conf.d/console.conf",
  ]

  concat { $sub_confs: }

  concat { $sub_confs_with_secrets:
    show_diff => true,
  }

  bacula::fileset { 'Default':
    files => ['/etc'],
  }

  bacula::job { "RestoreFiles-${director}":
    jobtype  => 'Restore',
    fileset  => 'Default',
    jobdef   => false,
    messages => 'Standard',
  }
}
