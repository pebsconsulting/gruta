package Gruta::Template::BASE;

sub templates {
	my $self	 = shift;

	my @r = ();

	if (opendir D, $self->{path}) {
		while (my $l = readdir D) {
			next if -d $self->{path} . '/' . $l;
			push @r, $l;
		}

		closedir D;
	}

	return @r;
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

	if (open F, $self->{path} . '/'. $template_id) {
		$content = join('', <F>);
		close F;
	}

	return $content;
}


sub save_template {
	my $self	= shift;
	my $template_id	= shift;
	my $content	= shift;

	$self->_assert($template_id);

	open F, '>' . $self->{path} . '/' . $template_id
		or die "Can't write template '$template_id'";

	print F $content;
	close F;
}


1;
