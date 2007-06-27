package Gruta::Data;

sub sources { return @{$_[0]->{sources}}; }

sub entry {
	my $self	= shift;
	my $topic	= shift;
	my $id		= shift;

	my $e = undef;
	my $ck = $topic . '/' . $id;

	if ($e = $self->{entry_cache}->{$ck}) {
		return $e;
	}

	foreach my $s ($self->sources()) {
		last if $e = $s->entry($topic, $id);
	}

	if (!defined($e)) {
		die("Invalid entry $topic / $id");
	}

	return $self->{entry_cache}->{$ck} = $e;
}


sub topic {
	my $self	= shift;
	my $topic	= shift;

	my $t = undef;

	foreach my $s ($self->sources()) {
		last if $t = $s->topic($topic);
	}

	if (!defined($t)) {
		$self->bang("Invalid topic $topic");
	}

	return $t;
}


sub new {
	my $class	= shift;
	my %args	= @_;

	my $g = \%args;
	bless($g, $class);

	$g->{entry_cache} = {};

	return $g;
}

sub run {
	my $self	= shift;
}

1;
