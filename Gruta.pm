package Gruta;

sub sources { return @{$_[0]->{sources}}; }
sub template { return $_[0]->{template}; }

sub _call {
	my $self	= shift;
	my $method	= shift;
	my $short	= shift;

	my @r = ();

	foreach my $s ($self->sources()) {
		if (my $m = $s->can($method)) {
			my @pr = $m->($s, @_);

			if (@pr) {
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

	foreach my $src ($self->sources()) {
		if ($src->topic( $topic_id ) and
			$story = $src->story($topic_id, $id)) {
			last;
		}
	}

	if (!defined($story)) {
		die('Invalid story ' . $ck);
	}

	if (my $rndr = $self->{renderers_h}->{$story->get('format')}) {
		$rndr->story($story);

		$self->_special_uri($story);
	}

	return $self->{story_cache}->{$ck} = $story;
}


sub stories { my $self = shift; return $self->_call('stories', 0); }
sub stories_by_date { my $self = shift; return $self->_call('stories_by_date', 1, @_); }
sub search_stories { my $self = shift; return $self->_call('search_stories', 1, @_); }

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
		my $session = undef;

		foreach my $s ($self->sources()) {

			if ($s->can('purge_old_sessions') &&
			    $s->can('session')) {
				$s->purge_old_sessions();
				last if $session = $s->session($sid);
			}
		}

		if ($session) {
			$u = $s->user( $session->get('user_id') );

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
	my $u = undef;

	foreach my $s ($self->sources()) {
		if ($s->can('user') and $u = $s->user($user_id)) {
			my $p = $u->get('password');

			if (crypt($passwd, $p) eq $p) {
				# create new sid
				$sid = time() . $$;

				my $session = Gruta::Data::Session->new(
					id	=> $sid,
					time	=> time(),
					user_id	=> $user_id
				);

				$s->insert_session( $session );

				$u->set('sid', $sid);
				$self->auth($u);

				last;
			}
		}
	}

	return $sid;
}


sub logout {
	my $self	= shift;

	my $auth = undef;

	if ($auth = $self->auth() and my $sid = $auth->get('sid')) {
		my $src = $auth->{_driver};

		if (my $session = $src->session( $sid )) {
			$session->delete() if $session->can('delete');
		}

	}

	$self->auth($auth);
	return $self;
}


sub run {
	my $self	= shift;
}

sub _special_uri {
	my $self	= shift;
	my $story	= shift;

	my $body = $story->get('body');

	$body =~ s!topic://([\w\d_]+)!$self->template->link_to_topic($1)!ge;
	$body =~ s!story://([\w\d_]+)/([\w\d_]+)!$self->template->link_to_story($1,$2)!ge;

	$story->set('body', $body);
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

sub new {
	my $class	= shift;
	my %args	= @_;

	my $g = \%args;
	bless($g, $class);

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

	$g->template->data($g) if $g->{template};

	return $g;
}

1;
