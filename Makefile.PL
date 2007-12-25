use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.

sub MY::postamble {
return <<EOF;

install::
	mkdir -p /usr/share/gruta/templates/artemus
	install -m 644 templates/artemus/* /usr/share/gruta/templates/artemus
	mkdir -p /usr/share/gruta/templates/tt
	install -m 644 templates/tt/* /usr/share/gruta/templates/tt
EOF
}

WriteMakefile(
    'NAME'		=> 'Gruta',
    'dist'		=> { COMPRESS => gzip, SUFFIX => '.gz'},
    'VERSION_FROM'	=> 'Gruta.pm',
);
