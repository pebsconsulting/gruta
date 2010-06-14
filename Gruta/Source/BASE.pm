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


sub related_stories {
	my $self	= shift;
	my $story	= shift;
	my $max		= shift || 5;

	my @ret = ();

	# get tags
	my @tags = $story->tags();

	foreach my $i ($self->stories_by_tag(undef, join(",", @tags))) {
		# if it's the same story, ignore
		if ($i->[1] eq $story->get('id') &&
					$i->[0] eq $story->get('topic_id')) {
			next;
		}

		push(@ret, $i);

		# enough of them? done
		if (scalar(@ret) >= $max) {
			last;
		}
	}

	return sort { $a->[2] cmp $b->[2] } @ret;
}

1;
