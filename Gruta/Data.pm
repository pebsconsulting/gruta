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
sub vfields { return qw(sid); }

package Gruta::Data::Session;

use base 'Gruta::Data::BASE';

sub fields { return qw(id time user_id ip); }

1;
