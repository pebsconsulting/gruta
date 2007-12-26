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

sub is_editor {
	my $self	= shift;
	my $user	= shift; # Gruta::Data::User

	return $user && ($user->get('is_admin') || 
		$self->get('editors') =~ m{\b$user->get('id')\b}) ? 1 : 0;
}

package Gruta::Data::Story;

use base 'Gruta::Data::BASE';

use Carp;

sub fields { return qw(id topic_id title date date2 userid format hits ctime content); }
sub vfields { return qw(abstract body); }

sub _assert {
	my $self	= shift;

	$self->SUPER::_assert();

	my $topic_id = $self->get('topic_id') || '';
	$topic_id =~ /^[\d\w_-]+$/ or croak "Bad topic_id";

	return $self;
}

sub date { return Gruta::Data::format_date($_[0]->get('date'), $_[1]); }
sub date2 { return Gruta::Data::format_date($_[0]->get('date2'), $_[1]); }

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

sub new_id {
	my $self	= shift;

	return sprintf ('%08x', int(rand(0xffffffff)));
}

sub is_visible {
	my $self	= shift;
	my $user	= shift; # Gruta::Data::User

	return !$user && $self->get('date') > Gruta::Data::today() ? 0 : 1;
}


package Gruta::Data::User;

use base 'Gruta::Data::BASE';

sub fields { return qw(id username email password can_upload is_admin xdate); }
sub vfields { return qw(sid); }

sub xdate { return Gruta::Data::format_date($_[0]->get('xdate'), $_[1]); }

sub password {
	my $self	= shift;
	my $passwd	= shift;

	my $salt = sprintf('%02d', rand(100));
	my $pw = crypt($passwd, $salt);

	$self->set('password', $pw);

	return $self;
}


package Gruta::Data::Session;

use base 'Gruta::Data::BASE';

sub fields { return qw(id time user_id ip); }

package Gruta::Data;

sub format_date {
	my $date	= shift;
	my $format	= shift;

	if ($format) {
		my ($y, $m, $d, $H, $M, $S) = ($date =~
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
		$format = $date;
	}

	return $format;
}


sub today {
	my $format	= shift;

	my ($S,$M,$H,$d,$m,$y) = (localtime)[0..5];

	my $date = sprintf('%04d%02d%02d%02d%02d%02d',
		1900 + $y, $m + 1, $d, $H, $M, $S);

	return Gruta::Data::format_date($date, $format);
}


1;
