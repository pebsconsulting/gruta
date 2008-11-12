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

1;
