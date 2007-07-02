package Gruta::Data;

package Gruta::Data::BASE;

sub fields { return (); }
sub vfields { return (); }

sub new {
	my $class	= shift;
	my %args	= @_;

	my $self = bless({ }, $class);

	foreach my $k ($self->fields(), $self->vfields()) {
		$self->{$k} = $args{$k};
	}

	return $self;
}

sub get {
	my $self	= shift;
	my $field	= shift;

	die 'get ' . ref($self) . " field '$field'?" unless exists $self->{$field};

	return $self->{$field};
}

sub set {
	my $self	= shift;
	my $field	= shift;

	die 'set ' . ref($self) . " field '$field'?" unless exists $self->{$field};

	$self->{$field} = shift;

	return $self->{$field};
}


package Gruta::Data::Topic;

use base 'Gruta::Data::BASE';

sub fields { return qw(id name editors max_stories internal); }

package Gruta::Data::Story;

use base 'Gruta::Data::BASE';

sub fields { return qw(id topic_id title date userid format hits ctime content); }
sub vfields { return qw(abstract body); }

package Gruta::Data::User;

use base 'Gruta::Data::BASE';

sub fields { return qw(id username email password can_upload is_admin); }

##################################################

package Gruta::Data;

sub sources { return @{$_[0]->{sources}}; }
sub template { return $_[0]->{template}; }

sub topic {
	my $self	= shift;
	my $id		= shift;

	my $t = undef;

	foreach my $s ($self->sources()) {
		last if $t = $s->topic($id);
	}

	if (!defined($t)) {
		die('Invalid topic ' . $id);
	}

	return $t;
}

sub topics {
	my $self	= shift;

	my @r = ();

	foreach my $s ($self->sources()) {
		@r = (@r, $s->topics());
	}

	return @r;
}


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
		last if $story = $src->story($topic_id, $id);
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


sub stories {
	my $self	= shift;
	my $topic_id	= shift;

	my @r = ();

	foreach my $s ($self->sources()) {
		@r = (@r, $s->stories( $topic_id ));
	}

	return @r;
}


sub stories_by_date {
	my $self	= shift;

	my @r = ();

	foreach my $src ($self->sources()) {
		last if @r = $src->stories_by_date( @_ );
	}

	return @r;
}


sub user {
	my $self	= shift;
	my $id		= shift;

	my $u = undef;

	foreach my $s ($self->sources()) {
		last if $u = $s->user($id);
	}

	if (!defined($u)) {
		die('Invalid user ' . $id);
	}

	return $u;
}

sub users {
	my $self	= shift;

	my @r = ();

	foreach my $s ($self->sources()) {
		@r = (@r, $s->users());
	}

	return @r;
}


sub _insert {
	my $self	= shift;
	my $obj		= shift;
	my $method	= shift;

	foreach my $s ($self->sources()) {
		if ($s->can($method)) {
			$s->$method->($obj);
		}
	}

	return $self;
}

sub insert_topic { $_[0]->_insert($_[1], 'insert_topic'); }
sub insert_user { $_[0]->_insert($_[1], 'insert_user'); }
sub insert_story { $_[0]->_insert($_[1], 'insert_story'); }


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


sub copy {
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

1;
