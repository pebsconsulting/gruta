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

	if (!exists $self->data->{args}->{dummy_touch}) {
		my $r = 0;
		my $t = $self->template('cfg_top_ten_num');

		if ($t && $t->get('content') <= 0) {
			$r = 1;
		}

		$self->data->{args}->{dummy_touch} = $r;
	}

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


sub stories_by_date {
	my $self	= shift;
	my $topics	= shift;
	my %args	= @_;

    if ($topics) {
        $args{topics} = $topics;
    }
    if ($args{tags}) {
        $args{tags} = [split(/\s*,\s*/, $args{tags})];
    }

    return $self->story_set(%args);
}


sub stories_by_text {
    my $self	= shift;
    my $topics	= shift;
    my $query	= shift;
    my $future	= shift;

    my %args = (
        content => $query,
        future  => $future,
        order   => 'title'
    );

    if ($topics) {
        $args{topics} = $topics;
    }

    return $self->story_set(%args);
}


sub stories_by_tag {
    my $self    = shift;
    my $topics  = shift;
    my $tag     = shift;
    my $future  = shift;

    my @r = ();

    if ($tag) {
        my %args = (
            topics  => $topics,
            future  => $future,
            order   => 'title',
            tags    => [map { lc($_) } split(/\s*,\s*/, $tag)]
        );

        @r = $self->story_set(%args);
    }

    return @r;
}


sub stories_top_ten {
    my $self    = shift;
    my $num     = shift;

    my %args = (
        order   => 'hits',
        num     => $num
    );

    return $self->story_set(%args);
}


sub related_stories {
    my $self    = shift;
    my $story   = shift;
    my $max     = shift || 5;

    my @ret = ();

    # get tags
    my @tags = $story->tags();

    my $id          = $story->get('id');
    my $topic_id    = $story->get('topic_id');

    if (scalar(@tags)) {
        my %h = ();
        my @ret1 = ();
        my @ret2 = ();

        # mark the current story as already used
        $h{$topic_id . '/' . $id} = 1;

        foreach my $i ($self->stories_by_tag(undef, join(",", @tags))) {
            my $k = $i->[0] . '/' . $i->[1];

            if (!exists($h{$k})) {
                push(@ret1, $i);
                $h{$k}++;
            }
        }

        @ret1 = sort { $b->[2] cmp $a->[2] } @ret1;

        # if not enough, get others, tag by tag
        if (0 && scalar(@ret1) < $max) {
            while (scalar(@tags)) {
                foreach my $i ($self->stories_by_tag(undef, shift(@tags))) {
                    my $k = $i->[0] . '/' . $i->[1];

                    if (!exists($h{$k})) {
                        push(@ret2, $i);
                        $h{$k}++;
                    }
                }
            }

            @ret2 = sort { $b->[2] cmp $a->[2] } @ret2;
        }

        @ret = (@ret1, @ret2);
    }

    return scalar(@ret) > $max ? @ret[0 .. ($max - 1)] : @ret;
}


sub untagged_stories {
    my $self = shift;

    my %r = ();

    foreach my $topic_id ($self->topics()) {
        foreach my $story_id ($self->stories($topic_id)) {
            my $story = $self->story($topic_id, $story_id);

            if ($story->get('date') gt Gruta::Data::today()) {
                next;
            }
    
            if (!$story->tags()) {
                $r{$story->get('title')} =
                    [ $topic_id, $story_id, $story->get('date') ];
            }
        }
    }

    return map { $r{$_} } sort keys %r;
}

1;
