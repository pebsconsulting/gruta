package Webon2::Data::Entry;

sub new { my $class = shift; return bless({ @_ }, $class); }

sub source { $_[0]->{source}; }

sub get {
	my $self	= shift;
	my $part	= shift;

	if (!$self->{$part}) {
		$self->source->load_entry($self, $part);
	}

	return $self->{$part};
}

sub set { $_[0]->{$_[1]} = $_[2]; }

sub render {
	my $self	= shift;
}

1;
