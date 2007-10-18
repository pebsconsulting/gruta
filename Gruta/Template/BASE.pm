package Gruta::Template::BASE;

sub templates {
	my $self	 = shift;

	my @r = ( );

	foreach my $p (split(':', $self->{path})) {
		if (opendir D, $p) {
			while (my $l = readdir D) {
				next if -d $p . '/' . $l;
				push @r, $l;
			}

			closedir D;
		}
	}

	return sort @r;
}


sub _assert {
	my $self	= shift;
	my $template_id	= shift;

	if (not $template_id =~ /^[-\w\d-]+$/) {
		die "Invalid template '$template_id'";
	}

	return $self;
}


sub template {
	my $self	= shift;
	my $template_id	= shift;

	$self->_assert($template_id);

	my $content = undef;

	foreach my $p (split(':', $self->{path})) {
		if (open F, $p . '/'. $template_id) {
			$content = join('', <F>);
			close F;

			last;
		}
	}

	return $content;
}


sub save_template {
	my $self	= shift;
	my $template_id	= shift;
	my $content	= shift;

	$self->_assert($template_id);

	# only can be saved on the first directory
	my ($p) = split(':', $self->{path});

	open F, '>' . $p . '/' . $template_id
		or die "Can't write template '$template_id'";

	print F $content;
	close F;
}


1;
