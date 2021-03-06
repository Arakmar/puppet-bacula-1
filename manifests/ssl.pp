# Class: bacula::ssl
#
# Manage the SSL deployment for bacula components, Director, Storage, and File.
class bacula::ssl (
  $ssl_dir    = $bacula::params::ssl_dir,
  $conf_dir   = $bacula::params::conf_dir,
  $certfile   = $bacula::params::certfile,
  $keyfile    = $bacula::params::keyfile,
  $cafile     = $bacula::params::cafile,
  $packages   = $bacula::params::bacula_common_packages,
  $user       = $bacula::params::bacula_user,
  $conf_user  = $bacula::params::bacula_user,
  $conf_group = $bacula::params::bacula_group,
) inherits bacula::params {

  $ssl_files = [
    $certfile,
    $keyfile,
    $cafile
  ]

  File {
    owner   => $user,
    group   => $group,
    mode    => '0640',
  }

  file { "${conf_dir}/ssl":
    ensure => 'directory',
    require => File[$conf_dir]
  }

  file { $certfile:
    source  => "${ssl_dir}/certs/${::clientcert}.pem",
    require => File["${conf_dir}/ssl"],
  }

  file { $keyfile:
    source  => "${ssl_dir}/private_keys/${::clientcert}.pem",
    require => File["${conf_dir}/ssl"],
  }

  # Now export our key and cert files so the director can collect them,
  # while we've still realized the actual files, except when we're on
  # the director already.
  #unless ($::fqdn == $bacula::params::director_name) {
  #  @@bacula::ssl::certfile { $::clientcert: }
  #  @@bacula::ssl::keyfile  { $::clientcert: }
  #}

  file { $cafile:
    ensure  => 'file',
    source  => "${ssl_dir}/certs/ca.pem",
    require => File["${conf_dir}/ssl"],
  }

  exec { 'generate_bacula_dhkey':
    command => 'openssl dhparam -out dh2048.pem -5 2048',
    path    => '/usr/bin:/usr/sbin:/bin:/sbin:/usr/local/bin:/usr/local/sbin',
    cwd     => "${conf_dir}/ssl",
    creates => "${conf_dir}/ssl/dh2048.pem",
    timeout => 0,
    require => File["${conf_dir}/ssl"],
  }
}
