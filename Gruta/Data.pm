package Gruta::Data;

use strict;
use warnings;

package Gruta::Data::BASE;

use Carp;

sub fields { return (); }
sub vfields { return (); }
sub afields { return ($_[0]->fields(), $_[0]->vfields()); }

sub source {
	my $self	= shift;

	if (@_) {
		$self->{_source} = shift;
	}

	return $self->{_source};
}


sub _assert {
	my $self	= shift;

	my $id = $self->get('id') || '';
	$id =~ /^[\d\w_-]+$/ or croak "Bad id [$id]";

	return $self;
}

sub new {
	my $class	= shift;
	my %args	= @_;

	my $self = bless({ }, $class);

	foreach my $k ($self->afields()) {
		$self->{$k} = $args{$k};
	}

	return $self;
}

sub get {
	my $self	= shift;
	my $field	= shift;

	croak 'get ' . ref($self) . " field '$field'?" unless exists $self->{$field};

	return $self->{$field};
}

sub set {
	my $self	= shift;
	my $field	= shift;

	croak 'set ' . ref($self) . " field '$field'?" unless exists $self->{$field};

	$self->{$field} = shift;

	return $self->{$field};
}


package Gruta::Data::Topic;

use base 'Gruta::Data::BASE';

sub fields { return qw(id name editors max_stories internal); }

package Gruta::Data::Story;

use base 'Gruta::Data::BASE';

use Carp;

sub fields { return qw(id topic_id title date userid format hits ctime content); }
sub vfields { return qw(tags abstract body); }

sub _assert {
	my $self	= shift;

	$self->SUPER::_assert();

	my $topic_id = $self->get('topic_id') || '';
	$topic_id =~ /^[\d\w_-]+$/ or croak "Bad topic_id";

	return $self;
}

sub date {
	my $self	= shift;
	my $format	= shift;

	if (defined($format)) {
		my ($y, $m, $d, $H, $M, $S) = ($self->get('date') =~
			/^(\d{4})(\d{2})(\d{2})(\d{2})(\d{2})(\d{2})$/);

		$format =~ s/%Y/$y/g;
		$format =~ s/%y/$y/g;
		$format =~ s/%m/$m/g;
		$format =~ s/%d/$d/g;
		$format =~ s/%H/$H/g;
		$format =~ s/%M/$M/g;
		$format =~ s/%S/$S/g;
	}
	else {
		$format = $self->get('date');
	}

	return($format);
}

sub touch { return $_[0]; }

sub tags {
	my $self	= shift;
	my @ret		= undef;

	if (scalar(@_)) {
		$self->set('tags', [ @_ ]);
	}
	else {
		@ret = @{ $self->get('tags') };
	}

	return @ret;
}

package Gruta::Data::User;

use base 'Gruta::Data::BASE';

sub fields { return qw(id username email password can_upload is_admin); }
sub vfields { return qw(sid); }

package Gruta::Data::Session;

use base 'Gruta::Data::BASE';

sub fields { return qw(id time user_id ip); }

1;
