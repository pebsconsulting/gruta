package Webon2::Data;

sub drivers { return @{$_[0]->{drivers}}; }

sub topic {
	my $self	= shift;
	my $id		= shift;

	my $t = undef;

	foreach my $s ($self->drivers()) {
		last if $t = $s->topic($id);
	}

	if (!defined($t)) {
		die('Invalid topic ' . $id);
	}

	return $t;
}

sub topics {
	my $self	= shift;

	my @r = ();

	foreach my $s ($self->drivers()) {
		@r = (@r, $s->topics());
	}

	return @r;
}


sub story {
	my $self	= shift;
	my $topic_id	= shift;
	my $id		= shift;

	my $e = undef;
	my $ck = $topic . '/' . $id;

	if ($e = $self->{story_cache}->{$ck}) {
		return $e;
	}

	foreach my $s ($self->drivers()) {
		last if $e = $s->story($topic_id, $id);
	}

	if (!defined($e)) {
		die('Invalid story ' . $ck);
	}

	return $self->{story_cache}->{$ck} = $e;
}


sub new {
	my $class	= shift;
	my %args	= @_;

	my $g = \%args;
	bless($g, $class);

	$g->{story_cache} = {};

	if (ref($g->{drivers}) ne 'ARRAY') {
		$g->{drivers} = [ $g->{drivers} ];
	}

	return $g;
}

sub run {
	my $self	= shift;
}

1;
