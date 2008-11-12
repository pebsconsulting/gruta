package Gruta::Source::BASE;

use strict;
use warnings;
use Carp;

sub data {
	my $self	= shift;

	if (@_) {
		$self->{data} = shift;
	}

	return $self->{data};
}

sub dummy_touch {
	my $self	= shift;

	return $self->data->{args}->{dummy_touch};
}

1;
