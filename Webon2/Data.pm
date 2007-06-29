package Webon2::Data;

package Webon2::Data::BASE;

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


package Webon2::Data::Topic;

use base 'Webon2::Data::BASE';

sub fields { return qw(id name editors max_stories internal); }

package Webon2::Data::Story;

use base 'Webon2::Data::BASE';

sub fields { return qw(id topic_id title date userid format hits ctime content); }
sub vfields { return qw(abstract body); }

package Webon2::Data::User;

use base 'Webon2::Data::BASE';

sub fields { return qw(id username email password can_upload is_admin); }

##################################################

package Webon2::Data;

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
	my $ck = $topic . '/' . $id;

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

	$g->template->data($g);

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


1;
