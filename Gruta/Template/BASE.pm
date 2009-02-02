package Gruta::Template::BASE;

use Carp;

sub templates {
	my $self	 = shift;

	my %r = ( );

	foreach my $p (@{$self->{path}}) {
		if (opendir D, $p) {
			while (my $l = readdir D) {
				next if -d $p . '/' . $l;
				$r{$l}++;
			}

			closedir D;
		}
	}

	return sort keys(%r);
}


sub _assert {
	my $self	= shift;
	my $template_id	= shift;

	if (not $template_id =~ /^[-\w\d-]+$/) {
		croak "Invalid template '$template_id'";
	}

	return $self;
}


sub template {
	my $self	= shift;
	my $template_id	= shift;

	$self->_assert($template_id);

	my $content = undef;

	foreach my $p (@{$self->{path}}) {
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
	my $p = $self->{path}->[0];

	# delete all \r in content
	$content =~ s/\r//g;

	open F, '>' . $p . '/' . $template_id
		or croak "Can't write template '${p}/${template_id}'";

	print F $content;
	close F;
}


sub create {
	my $self	= shift;

	# create first directory
	my $p1 = $self->{path}->[0];

	if (! -d $p1) {
		mkdir $p1, 0755 or die "Cannot mkdir $p1";
	}

	return $self;
}

1;
