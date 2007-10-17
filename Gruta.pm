package Gruta;

use strict;
use warnings;

$Gruta::VERSION = '2.0-pre2';

sub sources { return @{$_[0]->{sources}}; }
sub template { return $_[0]->{template}; }
sub cgi { return $_[0]->{cgi}; }

sub today {
	my $self	= shift;

	if (not $self->{_today}) {
		my ($S,$M,$H,$d,$m,$y) = (localtime)[0..5];
		$self->{_today} =
			 sprintf("%04d%02d%02d%02d%02d%02d",
			1900 + $y, $m + 1, $d, $H, $M, $S);
	}

	return $self->{_today};
}

sub log {
	my $self	= shift;
	my $msg		= shift;

	print STDERR $self->{id}, ' ', scalar(localtime), ': ', $msg, "\n";
}


sub _call {
	my $self	= shift;
	my $method	= shift;
	my $short	= shift;

	my @r = ();

	foreach my $s ($self->sources()) {
		if (my $m = $s->can($method)) {
			my @pr = $m->($s, @_);

			if (@pr && $pr[0]) {
				@r = (@r, @pr);

				last if $short;
			}
		}
	}

	return wantarray ? @r : $r[0];
}

sub topic { my $self = shift; return $self->_call('topic', 1, @_); }
sub topics { my $self = shift; return $self->_call('topics', 0); }

sub user { my $self = shift; return $self->_call('user', 1, @_); }
sub users { my $self = shift; return $self->_call('users', 0); }

sub story {
	my $self	= shift;
	my $topic_id	= shift;
	my $id		= shift;

	my $story = undef;
	my $ck = $topic_id . '/' . $id;

	if ($story = $self->{story_cache}->{$ck}) {
		return $story;
	}

	if (not $story = $self->_call('story', 1, $topic_id, $id)) {
		return undef;
	}

	if (my $rndr = $self->{renderers_h}->{$story->get('format')}) {
		$rndr->story($story);
	}

	return $self->{story_cache}->{$ck} = $story;
}


sub stories { my $self = shift; return $self->_call('stories', 0, @_); }
sub stories_by_date { my $self = shift;
	return $self->_call('stories_by_date', 1, @_, 'today' => $self->today()); }
sub search_stories { my $self = shift; return $self->_call('search_stories', 1, @_); }

sub stories_top_ten {
	my $self = shift;

	my @l = $self->_call('stories_top_ten', 0, @_);

	return sort { $b->[0] cmp $a->[0] } @l;
}

sub stories_by_tag { my $self = shift; return $self->_call('stories_by_tag', 0, @_); }

sub tags {
	my $self = shift;

	my @l = $self->_call('tags', 0, @_);

	return sort { $b->[1] cmp $a->[1] } @l;
}

sub insert_topic { my $self = shift; $self->_call('insert_topic', 1, @_); return $self; }
sub insert_user { my $self = shift; $self->_call('insert_user', 1, @_); return $self; }
sub insert_story { my $self = shift; $self->_call('insert_story', 1, @_); return $self; }


sub auth {
	my $self	= shift;

	if (@_) { $self->{auth} = shift; }	# Gruta::Data::User

	return $self->{auth};
}


sub auth_from_sid {
	my $self	= shift;
	my $sid		= shift;

	my $u = undef;

	if ($sid) {
		$self->_call('purge_old_sessions', 0);

		if (my $session = $self->_call('session', 1, $sid)) {
			$u = $session->source->user( $session->get('user_id') );
			$u->set('sid', $sid);
			$self->auth($u);
		}
	}

	return $u;
}


sub login {
	my $self	= shift;
	my $user_id	= shift;
	my $passwd	= shift;

	my $sid = undef;

	if (my $u = $self->user( $user_id )) {

		my $p = $u->get('password');

		if (crypt($passwd, $p) eq $p) {
			# create new sid
			$sid = time() . $$;

			my $session = Gruta::Data::Session->new(
				id	=> $sid,
				time	=> time(),
				user_id	=> $user_id
			);

			$u->source->insert_session( $session );

			$u->set('sid', $sid);
			$self->auth($u);
		}
	}

	return $sid;
}


sub logout {
	my $self	= shift;

	if (my $auth = $self->auth()) {
		if( my $sid = $auth->get('sid')) {
			if (my $session = $auth->source->session( $sid )) {
				$session->delete() if $session->can('delete');
			}
		}
	}

	$self->auth( undef );
	return $self;
}


sub _link_to_topic {
	my $self	= shift;
	my $topic_id	= shift;

	my $ret = undef;

	if (my $t = $self->topic($topic_id)) {
		$ret = "<a href='?t=TOPIC;topic=$topic_id'>" .
			$t->get('name') . '</a>';
	}
	else {
		$ret = "Bad topic $topic_id";
	}

	return $ret;
}


sub _link_to_story {
	my $self	= shift;
	my $topic_id	= shift;
	my $story_id	= shift;

	my $ret = undef;

	if (my $s = $self->story($topic_id, $story_id)) {
		$ret = "<a href='?t=STORY;topic=$topic_id;id=$story_id'>" .
			$s->get('title') . '</a>';
	}
	else {
		$ret = "Bad story '$topic_id/$story_id'";
	}

	return $ret;
}


sub special_uris {
	my $self	= shift;
	my $string	= shift;

	$string =~ s!topic://([\w\d_]+)!$self->_link_to_topic($1)!ge;
	$string =~ s!story://([\w\d_]+)/([\w\d_]+)!$self->_link_to_story($1,$2)!ge;

	return $string;
}


sub transfer_to_source {
	my $self	= shift;
	my $dst		= shift;

	foreach my $id ($self->users()) {
		my $u = $self->user($id);
		$dst->insert_user($u);
	}

	foreach my $topic_id ($self->topics()) {
		my $t = $self->topic($topic_id);
		$dst->insert_topic($t);

		foreach my $id ($self->stories($topic_id)) {
			my $s = $self->story($topic_id, $id);
			$dst->insert_story($s);
		}
	}

	return $self;
}


sub flush_story_cache {
	my $self	= shift;

	$self->{story_cache} = {};
}


sub new {
	my $class	= shift;

	my $g = bless( { @_ } , $class);

	$g->{id} ||= 'Gruta';
	$g->{story_cache} = {};

	if (ref($g->{sources}) ne 'ARRAY') {
		$g->{sources} = [ $g->{sources} ];
	}
	if (ref($g->{renderers}) ne 'ARRAY') {
		$g->{renderers} = [ $g->{renderers} ];
	}

	$g->{renderers_h} = {};

	foreach my $r (@{$g->{renderers}}) {
		$g->{renderers_h}->{$r->{renderer_id}} = $r;
	}

	$g->template->data($g)	if $g->{template};
	$g->cgi->data($g)	if $g->{cgi};

	return $g;
}

sub run {
	my $self	= shift;

	if ($self->{cgi}) {
		$self->cgi->run();
	}
}

1;
