package Gruta;

use strict;
use warnings;

use locale;

use Gruta::Data;

$Gruta::VERSION			= '2.1.1';
$Gruta::VERSION_CODENAME	= '"Calenzano"';

sub sources { return @{$_[0]->{sources}}; }
sub template { return $_[0]->{template}; }
sub cgi { return $_[0]->{cgi}; }

sub version { return $Gruta::VERSION . ' ' . $Gruta::VERSION_CODENAME; }

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

	if (!exists($self->{calls}->{$method})) {

		# cache all calls in the sources
		my @c = ();

		foreach my $s ($self->sources()) {
			if (my $m = $s->can($method)) {
				push(@c, sub { return $m->($s, @_) });
			}
		}

		$self->{calls}->{$method} = [ @c ];
	}

	foreach my $m (@{ $self->{calls}->{$method}}) {
		my @pr = $m->(@_);

		if (@pr && $pr[0]) {
			@r = (@r, @pr);

			last if $short;
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

	if (! $topic_id || ! $id) {
		return undef;
	}

	my $story = undef;
	my $ck = $topic_id . '/' . $id;

	if ($story = $self->{story_cache}->{$ck}) {
		return $story;
	}

	if (not $story = $self->_call('story', 1, $topic_id, $id)) {
		return undef;
	}

	my $format = $story->get('format') || 'grutatxt';

	if (my $rndr = $self->{renderers_h}->{$format}) {
		$rndr->story($story);
	}

	return $self->{story_cache}->{$ck} = $story;
}


sub stories { my $self = shift; return $self->_call('stories', 0, @_); }

sub stories_by_date {
	my $self	= shift;
	my $topics	= shift;
	my %opts	= @_;

	my @r = sort { $b->[2] cmp $a->[2] } $self->_call('stories_by_date', 0, $topics, %opts);

	if ($opts{num} && scalar(@r) > $opts{num}) {
		@r = @r[0 .. $opts{num} - 1];
	}

	return @r;
}

sub search_stories {
	my $self	= shift;
	my $topic_id	= shift;

	my @l = $self->_call('search_stories', 1, $topic_id, @_);

	return sort { $self->story($topic_id, $a)->get('title') cmp
			$self->story($topic_id, $b)->get('title') } @l;
}

sub stories_top_ten {
	my $self = shift;

	my @l = $self->_call('stories_top_ten', 0, @_);

	return sort { $b->[0] <=> $a->[0] } @l;
}

sub stories_by_tag {
	my $self = shift;

	my @l = $self->_call('stories_by_tag', 0, @_);

	return sort { $self->story($a->[0], $a->[1])->get('title') cmp
			$self->story($b->[0], $b->[1])->get('title') } @l;
}

sub tags {
	my $self = shift;

	my @l = $self->_call('tags', 0, @_);

	return sort { $a->[0] cmp $b->[0] } @l;
}

sub insert_topic { my $self = shift; return $self->_call('insert_topic', 1, @_); }
sub insert_user { my $self = shift; return $self->_call('insert_user', 1, @_); }
sub insert_story { my $self = shift; return $self->_call('insert_story', 1, @_); }


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

			if ($u) {
				$u->set('sid', $sid);
				$self->auth($u);
			}
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

		# account expired? go!
		if (my $xdate = $u->get('xdate')) {
			if (Gruta::Data::today() > $xdate) {
				return undef;
			}
		}

		my $p = $u->get('password');

		if (Gruta::Data::crypt($passwd, $p) eq $p) {
			# create new sid
			my $session = Gruta::Data::Session->new(user_id	=> $user_id);

			$u->source->insert_session( $session );

			$sid = $session->get('id');
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


sub base_url { $_[0]->{args}->{base_url} || '' };

sub url {
	my $self	= shift;
	my $st		= shift || '';
	my %args	= @_;

	my $ret = $self->base_url();

	# strip all undefined or empty arguments
	%args = map { $_, $args{$_} } grep { $args{$_} } keys(%args);

	if ($self->{args}->{static_urls}) {
		my $kn = scalar(keys(%args));

		if ($st eq 'INDEX' && $kn == 0) {
			return $ret;
		}
		elsif ($st eq 'TOPIC' && $kn == 1) {
			return $ret . $args{topic} . '/';
		}
		elsif ($st eq 'STORY' && $kn == 2) {
			return $ret . $args{topic} . '/' . $args{id} . '.html';
		}
	}

	if ($st) {
		$args{t} = $st;

		$ret .= '?' . join(';', map { "$_=$args{$_}" } sort keys(%args));
	}

	return $ret;
}


sub _topic_special_uri {
	my $self	= shift;
	my $topic_id	= shift;

	my $ret = undef;

	if (my $t = $self->topic($topic_id)) {
		$ret = sprintf('<a href="%s">%s</a>',
			$self->url('TOPIC', 'topic' => $topic_id),
			$t->get('name')
		);
	}
	else {
		$ret = "Bad topic $topic_id";
	}

	return $ret;
}


sub _story_special_uri {
	my $self	= shift;
	my $topic_id	= shift;
	my $story_id	= shift;

	my $ret = undef;

	if (my $s = $self->story($topic_id, $story_id)) {
		$ret = sprintf('<a href="%s">%s</a>',
			$self->url('STORY',
				'topic' => $topic_id,
				'id' => $story_id
			),
			$s->get('title')
		);
	}
	else {
		$ret = "Bad story '$topic_id/$story_id'";
	}

	return $ret;
}


sub _img_special_uri {
	my $self	= shift;
	my $src		= shift;
	my $class	= shift;

	my $r = sprintf('<img src = "%simg/%s" />',
		$self->base_url(), $src
	);

	if ($class) {
		$r = "<span class = '$class'>" . $r . '</span>';
	}

	return $r;
}


sub _content_special_uri {
	my $self	= shift;
	my $topic_id	= shift;
	my $story_id	= shift;
	my $field	= shift;

	my $ret = undef;

	if (my $s = $self->story($topic_id, $story_id)) {
		$ret = $self->special_uris($s->get($field));
	}
	else {
		$ret = "Bad story '$topic_id/$story_id'";
	}

	return $ret;
}



sub special_uris {
	my $self	= shift;
	my $string	= shift;

	$string =~ s!topic://([\w\d_-]+)!$self->_topic_special_uri($1)!ge;
	$string =~ s!story://([\w\d_-]+)/([\w\d_-]+)!$self->_story_special_uri($1,$2)!ge;
	$string =~ s!img://([\w\d_\.-]+)/?([\w\d_-]*)!$self->_img_special_uri($1,$2)!ge;
	$string =~ s!body://([\w\d_-]+)/([\w\d_-]+)!$self->_content_special_uri($1,$2,'body')!ge;
	$string =~ s!abstract://([\w\d_-]+)/([\w\d_-]+)!$self->_content_special_uri($1,$2,'abstract')!ge;

	return $string;
}


sub transfer_to_source {
	my $self	= shift;
	my $dst		= shift;

	foreach my $id ($self->users()) {
		my $u = $self->user($id);
		$dst->insert_user($u);
	}

	foreach my $topic_id (sort $self->topics()) {
		my $t = $self->topic($topic_id);

		my $nti = $topic_id;

		# is it an archive?
		if ($nti =~ /-arch$/) {
			# don't insert topic, just rename
			$nti =~ s/-arch$//;
		}
		else {
			$dst->insert_topic($t);
		}

		foreach my $id ($self->stories($topic_id)) {

			# get story and its tags
			my $s = $self->story($topic_id, $id);
			my @tags = $s->tags();

			# set new topic
			$s->set('topic_id', $nti);

			my $ns = $dst->insert_story($s);

			if (@tags) {
				$ns->tags(@tags);
			}
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

	$g->{id}		||= 'Gruta';
	$g->{args}		||= {};

	$g->{story_cache}	= {};
	$g->{renderers_h}	= {};
	$g->{calls}		= {};

	if ($g->{sources}) {
		if (ref($g->{sources}) ne 'ARRAY') {
			$g->{sources} = [ $g->{sources} ];
		}

		foreach my $s (@{$g->{sources}}) {
			$s->data($g);
		}
	}

	if ($g->{renderers}) {
		if (ref($g->{renderers}) ne 'ARRAY') {
			$g->{renderers} = [ $g->{renderers} ];
		}

		foreach my $r (@{$g->{renderers}}) {
			$g->{renderers_h}->{$r->{renderer_id}} = $r;
		}
	}

	if ($g->{template}) {
		$g->template->data($g);
	}

	if ($g->{cgi}) {
		$g->cgi->data($g);
	}

	return $g;
}

sub run {
	my $self	= shift;

	if ($self->{cgi}) {
		$self->cgi->run();
	}
}

1;
