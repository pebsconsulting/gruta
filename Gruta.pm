package Gruta;

use strict;
use warnings;

use locale;

use Gruta::Data;

$Gruta::VERSION			= '2.2.0-dev';
$Gruta::VERSION_CODENAME	= '"Osmannoro"';

sub source {
	$_[0]->{source};
}

sub template {
	$_[0]->{template};
}

sub cgi {
	$_[0]->{cgi};
}

sub version {
	$Gruta::VERSION . ' ' . $Gruta::VERSION_CODENAME;
}

sub log {
	my $self	= shift;
	my $msg		= shift;

	print STDERR $self->{id}, ' ', scalar(localtime), ': ', $msg, "\n";
}


sub render {
	my $self	= shift;
	my $story	= shift; # Gruta::Data::Story

	my $format = $story->get('format') || 'grutatxt';

	if (my $rndr = $self->{renderers_h}->{$format}) {
		$rndr->story($story);
	}
}


sub auth {
	my $self	= shift;

	if (@_) {
		$self->{auth} = shift;	# Gruta::Data::User
	}

	return $self->{auth};
}


sub session {
	my $self	= shift;

	if (@_) {
		$self->{session} = shift;	# Gruta::Data::Session
	}

	return $self->{session};
}


sub auth_from_sid {
	my $self	= shift;
	my $sid		= shift;

	my $u = undef;

	if ($sid) {
		$self->source->purge_old_sessions();

		if (my $session = $self->source->session($sid)) {
			$u = $session->source->user( $session->get('user_id') );

			if ($u) {
				$self->auth($u);
				$self->session($session);
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

	if (my $u = $self->source->user( $user_id )) {

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
			$self->source->insert_session($session);

			# store user and session
			$self->auth($u);
			$self->session($session);

			# and return sid to signal a valid login
			$sid = $session->get('id');

		}
	}

	return $sid;
}


sub logout {
	my $self	= shift;

	if (my $session = $self->session()) {
		$session->delete();
	}

	$self->auth(undef);
	$self->session(undef);

	return $self;
}


sub base_url {
	$_[0]->{args}->{base_url} || ''
};

sub url {
	my $self	= shift;
	my $st		= shift || '';
	my %args	= @_;

	if (scalar(@_) % 2) {
		$self->log('Bad url: ' . join(';', $st, @_));
	}

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

	if (my $t = $self->source->topic($topic_id)) {
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

	if (my $s = $self->source->story($topic_id, $story_id)) {
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

	if (my $s = $self->source->story($topic_id, $story_id)) {
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

	foreach my $id ($self->source->users()) {
		my $u = $self->source->user($id);
		$dst->insert_user($u);
	}

	foreach my $topic_id (sort $self->source->topics()) {
		my $t = $self->source->topic($topic_id);

		my $nti = $topic_id;

		# is it an archive?
		if ($nti =~ /-arch$/) {
			# don't insert topic, just rename
			$nti =~ s/-arch$//;
		}
		else {
			$dst->insert_topic($t);
		}

		foreach my $id ($self->source->stories($topic_id)) {

			# get story and its tags
			my $s = $self->source->story($topic_id, $id);
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


sub new {
	my $class	= shift;

	my $g = bless( { @_ } , $class);

	$g->{id}		||= 'Gruta';
	$g->{args}		||= {};

	$g->{renderers_h}	= {};

	if ($g->{sources}) {
		if (ref($g->{sources}) ne 'ARRAY') {
			$g->{sources} = [ $g->{sources} ];
		}

		if (!$g->{source}) {
			$g->{source} = (@{$g->{sources}})[0];
		}
	}

	if ($g->{source}) {
		$g->source->data($g);
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
