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

	my $id			= $story->get('id');
	my $topic_id	= $story->get('topic_id');

	if (scalar(@tags)) {
		my %h = ();
		my @ret1 = ();
		my @ret2 = ();

		# mark the current story as already used
		$h{$topic_id . '/' . $id} = 1;

		foreach my $i ($self->stories_by_tag(undef, join(",", @tags))) {
			my $k = $i->[0] . '/' . $i->[1];

			if (exists($h{$k})) {
				next;
			}

			push(@ret1, $i);
			$h{$k}++;
		}

		@ret1 = sort { $b->[2] cmp $a->[2] } @ret1;

		# if not enough, get others, tag by tag
		while (scalar(@ret1) + scalar(@ret2) < $max && scalar(@tags)) {
			foreach my $i ($self->stories_by_tag(undef, shift(@tags))) {
				my $k = $i->[0] . '/' . $i->[1];

				if (exists($h{$k})) {
					next;
				}

				push(@ret2, $i);
				$h{$k}++;
			}
		}

		@ret2 = sort { $b->[2] cmp $a->[2] } @ret2;

		@ret = (@ret1, @ret2);
	}

	return scalar(@ret) > $max ? @ret[0 .. ($max - 1)] : @ret;
}

1;
