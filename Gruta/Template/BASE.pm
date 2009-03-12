package Gruta::Template::BASE;

use Carp;

sub templates {
	my $self	 = shift;

	my %r = ();

	# add optional template names from the arguments
	foreach my $p (@_) {
		$r{$p}++;
	}

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

1;
