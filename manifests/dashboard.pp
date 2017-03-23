# == Class: murano::dashboard
#
#  murano dashboard package
#
# === Parameters
#
# [*package_ensure*]
#  (Optional) Ensure state for package
#  Defaults to 'present'
#
# [*api_url*]
#  (Optional) DEPRECATED: Use murano::keystone::auth to configure keystone::endpoint for Murano API instead
#  API url for murano-dashboard
#  Defaults to 'undef'
#
# [*repo_url*]
#  (Optional) Application repository URL for murano-dashboard
#  Defaults to 'undef'
#
# [*enable_glare*]
#  (Optional) Whether Murano to use Glare API (ex Glance v3 API)
#  Defaults to false
#
# [*collect_static_script*]
#  (Optional) Path to horizon manage utility
#  Defaults to '/usr/share/openstack-dashboard/manage.py'
#
# [*metadata_dir*]
#  (Optional) Directory to store murano dashboard metadata cache
#  Defaults to '/var/cache/murano-dashboard'
#
# [*max_file_size*]
#  (Optional) Maximum allowed filesize to upload
#  Defaults to '5'
#
# [*dashboard_debug_level*]
#  (Optional) Murano dashboard logging level
#  Defaults to 'DEBUG'
#
# [*client_debug_level*]
#  (Optional) Murano client logging level
#  Defaults to 'ERROR'
#
# [*sync_db*]
#  (Optional) Whether to sync database
#  Default to 'true'
#
# [*manage_horizon*]
# (Optional) Whether horizon's conf is managed here or externally
# Default to 'true'
#
class murano::dashboard(
  $package_ensure        = 'present',
  $repo_url              = undef,
  $enable_glare          = false,
  $collect_static_script = '/usr/share/openstack-dashboard/manage.py',
  $metadata_dir          = '/var/cache/murano-dashboard',
  $max_file_size         = '5',
  $dashboard_debug_level = 'DEBUG',
  $client_debug_level    = 'ERROR',
  $sync_db               = true,
  $manage_horizon        = true,
  # DEPRECATED PARAMETERS
  $api_url               = undef,
) {

  include ::murano::params

  if $api_url {
    warning('Usage of api_url is deprecated. Use murano::keystone::auth to configure keystone::endpoint for Murano API instead.')
  }

  package { 'murano-dashboard':
    ensure => $package_ensure,
    name   => $::murano::params::dashboard_package_name,
    tag    => ['openstack', 'murano-packages'],
  }

  if $manage_horizon { concat { $::murano::params::local_settings_path: } }

  concat::fragment { 'original_config':
    target => $::murano::params::local_settings_path,
    source => $::murano::params::local_settings_path,
    order  => 1,
  }

  concat::fragment { 'murano_dashboard_section':
    target  => $::murano::params::local_settings_path,
    content => template('murano/local_settings.py.erb'),
    order   => 2,
  }

  exec { 'clean_horizon_config':
    command => "sed -e '/^## MURANO_CONFIG_BEGIN/,/^## MURANO_CONFIG_END ##/ d' -i ${::murano::params::local_settings_path}",
    onlyif  => "grep '^## MURANO_CONFIG_BEGIN' ${::murano::params::local_settings_path}",
    path    => [ '/bin/', '/sbin/', '/usr/bin/', '/usr/sbin/' ],
  }

  if $::os_package_type == 'ubuntu' {
    $collect_static_command = "${collect_static_script} collectstatic --noinput"
  } else {
    $collect_static_command = "${collect_static_script} collectstatic --noinput --clear"
  }

  exec { 'django_collectstatic':
    command     => $collect_static_command,
    environment => [
      "APACHE_USER=${::apache::params::user}",
      "APACHE_GROUP=${::apache::params::group}",
    ],
    refreshonly => true,
  }

  exec { 'django_compressstatic':
    command     => "${collect_static_script} compress --force",
    environment => [
      "APACHE_USER=${::apache::params::user}",
      "APACHE_GROUP=${::apache::params::group}",
    ],
    refreshonly => true,
  }

  if $sync_db {
    exec { 'django_syncdb':
      command     => "${collect_static_script} migrate --noinput",
      environment => [
        "APACHE_USER=${::apache::params::user}",
        "APACHE_GROUP=${::apache::params::group}",
      ],
      refreshonly => true,
    }

    Exec['django_compressstatic'] ~>
      Exec['django_syncdb'] ~>
        Service <| title == 'httpd' |>
  }

  Package['murano-dashboard'] ->
    Exec['clean_horizon_config'] ->
      Concat[$::murano::params::local_settings_path] ->
        Service <| title == 'httpd' |>

  Package['murano-dashboard'] ~>
    Exec['django_collectstatic'] ~>
      Exec['django_compressstatic'] ~>
        Service <| title == 'httpd' |>
}
