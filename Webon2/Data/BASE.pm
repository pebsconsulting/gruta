package Webon2::Data::BASE;

sub fields { return (); }
sub vfields { return (); }

sub new {
	my $class	= shift;
	my %args	= @_;

	my $self = bless({ }, $class);

	foreach my $k ($self->fields(), $self->vfields()) {
		$self->{$k} = $args{$k};
	}

	return $self;
}

sub get {
	my $self	= shift;
	my $field	= shift;

	die 'get ' . ref($self) . " field '$field'?" unless exists $self->{$field};

	return $self->{$field};
}

sub set {
	my $self	= shift;
	my $field	= shift;

	die 'set ' . ref($self) . " field '$field'?" unless exists $self->{$field};

	$self->{$field} = shift;

	return $self->{$field};
}

1;
