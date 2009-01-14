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


sub cache_story {
	my $self	= shift;
	my $topic_id	= shift;
	my $id		= shift;
	my $story	= shift;

	if (!$self->{story_cache}) {
		$self->{story_cache} = {};
	}

	my $ck = $topic_id . '/' . $id;

	if ($story) {
		$self->{story_cache}->{$ck} = $story;
	}
	else {
		$story = $self->{story_cache}->{$ck};
	}

	return $story;
}


1;
