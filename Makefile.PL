use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.

sub MY::postamble {
return <<'EOF';

install::
	rm -rf /usr/share/gruta/templates/artemus
	mkdir -p /usr/share/gruta/templates/artemus
	for l in templates/artemus/* ; do \
		echo $$l ; \
		mkdir -p /usr/share/gruta/$$l ; \
		install -m 644 $$l/* /usr/share/gruta/$$l ; \
	done
	rm -rf /usr/share/gruta/templates/art5
	mkdir -p /usr/share/gruta/templates/art5
	install -m 644 templates/art5/* /usr/share/gruta/templates/art5
EOF
}

WriteMakefile(
	'NAME'		=> 'Gruta',
	'dist'		=> { COMPRESS => gzip, SUFFIX => '.gz'},
	'VERSION_FROM'	=> 'Gruta.pm',
	'EXE_FILES' 	=> [ 'bin/gruta', 'bin/gruta-mksite' ],
	'INSTALLSCRIPT'	=> '/usr/local/bin',
);
