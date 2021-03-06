define webapp::python::instance($domain,
                                $ensure=present,
                                $aliases=[],
                                $mediaroot="",
                                $mediaprefix="",
                                $wsgi_module="",
                                $django=false,
                                $django_settings="",
                                $paste=false,
                                $paste_settings="",
                                $requirements=false,
                                $workers=1,
                                $timeout_seconds=30,
                                $monit_memory_limit=300,
                                $monit_cpu_limit=50) {

  $venv = "${webapp::python::venv_root}/$name"
  $src = "${webapp::python::src_root}/$name"

  $pidfile = "${python::gunicorn::rundir}/${name}.pid"
  $socket = "${python::gunicorn::rundir}/${name}.sock"

  $owner = $webapp::python::owner
  $group = $webapp::python::group

  file { $src:
    ensure => directory,
    owner => $owner,
    group => $group,
  }

  nginx::site { $name:
    ensure => $ensure,
    domain => $domain,
    aliases => $aliases,
    root => "/var/www/$name",
    mediaroot => $mediaroot,
    mediaprefix => $mediaprefix,
    upstreams => ["unix:${socket}"],
    owner => $owner,
    group => $group,
    require => Python::Gunicorn::Instance[$name],
  }

  python::venv::isolate { $venv:
    ensure => $ensure,
    requirements => $requirements ? {
      true => "$src/requirements.txt",
      false => undef,
      default => "$src/$requirements",
    },
  }

  python::gunicorn::instance { $name:
    ensure => $ensure,
    venv => $venv,
    src => $src,
    wsgi_module => $wsgi_module,
    django => $django,
    django_settings => $django_settings,
    paste => $paste,
    paste_settings => $paste_settings,
    workers => $workers,
    timeout_seconds => $timeout_seconds,
    require => $ensure ? {
      'present' => Python::Venv::Isolate[$venv],
      default => undef,
    },
    before => $ensure ? {
      'absent' => Python::Venv::Isolate[$venv],
      default => undef,
    },
  }

  $reload = "/etc/init.d/gunicorn-$name reload"

  monit::monitor { "gunicorn-$name":
    ensure => $ensure,
    pidfile => $pidfile,
    socket => $socket,
    checks => ["if totalmem > $monit_memory_limit MB for 2 cycles then exec \"$reload\"",
               "if totalmem > $monit_memory_limit MB for 3 cycles then restart",
               "if cpu > ${monit_cpu_limit}% for 2 cycles then alert"],
    require => $ensure ? {
      'present' => Python::Gunicorn::Instance[$name],
      default => undef,
    },
    before => $ensure ? {
      'absent' => Python::Gunicorn::Instance[$name],
      default => undef,
    },
  }
}
