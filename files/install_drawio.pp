file {'/opt/drawio-amd64-16.5.1.deb':
 ensure => file,
 path => '/opt/drawio-amd64-16.5.1.deb',
 source => 'puppet:///files/AstraVDI/drawio-amd64-16.5.1.deb',
 owner => 'root',
 group => 'root',
 mode => '0775',
}

exec {'sudo dpkg -i /opt/drawio-amd64-16.5.1.deb':
 path => '/usr/bin',
 subscribe => File['/opt/drawio-amd64-16.5.1.deb'],
 refreshonly => true,
}

