package Webon2::Data;

sub sources { return @{$_[0]->{sources}}; }

sub topic {
	my $self	= shift;
	my $id		= shift;

	my $t = undef;

	foreach my $s ($self->sources()) {
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

	foreach my $s ($self->sources()) {
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

	foreach my $s ($self->sources()) {
		last if $e = $s->story($topic_id, $id);
	}

	if (!defined($e)) {
		die('Invalid story ' . $ck);
	}

	return $self->{story_cache}->{$ck} = $e;
}


sub template {
	my $self	= shift;
	my $template	= shift;

	return $self->{template}->process( $self, $template );
}


sub new {
	my $class	= shift;
	my %args	= @_;

	my $g = \%args;
	bless($g, $class);

	$g->{story_cache} = {};

	if (ref($g->{sources}) ne 'ARRAY') {
		$g->{sources} = [ $g->{sources} ];
	}

	return $g;
}

sub run {
	my $self	= shift;
}

1;
