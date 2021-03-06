package Gruta::Data;

use strict;
use warnings;

package Gruta::Data::BASE;

use Carp;

sub fields {
	return ();
}

sub vfields {
	return ();
}

sub afields {
	return ($_[0]->fields(), $_[0]->vfields());
}

sub filter_field {
	return $_[2];
}

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
	$id =~ /^[\d\w_-]+$/ or confess "Bad id '$id' [" . ref($self) . '] ';

	return $self;
}

sub new {
	my $class	= shift;
	my %args	= @_;

	my $self = bless({ }, $class);

	foreach my $k ($self->afields()) {
		$self->{$k} = undef;
		$self->set($k, $args{$k});
	}

	return $self;
}

sub get {
	my $self	= shift;
	my $field	= shift;

	confess 'get ' . ref($self) . " field '$field'?" unless exists $self->{$field};

	return $self->{$field};
}

sub set {
	my $self	= shift;
	my $field	= shift;
	my $value	= shift;

	confess 'set ' . ref($self) . " field '$field'?" unless exists $self->{$field};

    if (exists $self->{prev}) {
        # store previous value
        $self->{prev}->{$field} = $self->{$field};
    }

	$self->{$field} = $self->filter_field($field, $value);

	return $self->{$field};
}


package Gruta::Data::Topic;

use base 'Gruta::Data::BASE';

sub fields {
	return qw(id name editors max_stories internal description);
}

sub filter_field {
	my $self	= shift;
	my $field	= shift;
	my $value	= shift;

	# ensure empty numeric values are 0
	if ($field =~ /^(max_stories|internal)$/ && !$value) {
		$value = 0;
	}

	return $value;
}

sub is_editor {
	my $self	= shift;
	my $user	= shift; # Gruta::Data::User

	return $user && ($user->get('is_admin') || 
		($self->get('editors') || '')
			=~ m{\b$user->get('id')\b}) ? 1 : 0;
}

package Gruta::Data::Story;

use base 'Gruta::Data::BASE';

use Carp;

sub fields {
	return qw(id topic_id title date date2 userid format hits ctime toc has_comments full_story content description abstract body image tags udate);
}

sub filter_field {
	my $self	= shift;
	my $field	= shift;
	my $value	= shift;

	# ensure empty numeric values are 0
	if ($field =~ /^(hits|ctime)$/ && !$value) {
		$value = 0;
	}

	return $value;
}

sub _assert {
	my $self	= shift;

	$self->SUPER::_assert();

	my $topic_id = $self->get('topic_id') || '';
	$topic_id =~ /^[\d\w_-]+$/ or croak "Bad topic_id";

	return $self;
}

sub date {
	return Gruta::Data::format_date($_[0]->get('date'), $_[1]);
}

sub date2 {
	return Gruta::Data::format_date($_[0]->get('date2'), $_[1]);
}

sub udate {
	return Gruta::Data::format_date($_[0]->get('udate'), $_[1]);
}

sub touch {
	return $_[0];
}

sub tags {
	my $self	= shift;
	my @ret		= undef;

	if (scalar(@_)) {
		$self->set('tags', join(',', @_));
	}
	else {
		@ret = split(/\s*,\s*/, $self->get('tags'));
	}

	return @ret;
}

sub new_id {
	my $self	= shift;

	my $id;

    my ($s, $m, $h, $d, $M, $y) = localtime(time());

    $id = sprintf("%02x%c%c%c%c%02x",
        $$ % 256,
        (($y + $m) % 25) + 97,
        (($d + $M) % 25) + 97,
        ($h % 25) + 97,
        ($s % 25) + 97,
        rand(0xff)
    );

	return $id;
}

sub is_visible {
	my $self	= shift;
	my $user	= shift; # Gruta::Data::User

	return !$user && $self->get('date') gt Gruta::Data::today() ? 0 : 1;
}


package Gruta::Data::User;

use base 'Gruta::Data::BASE';

sub fields {
	return qw(id username email password can_upload is_admin xdate);
}

sub filter_field {
	my $self	= shift;
	my $field	= shift;
	my $value	= shift;

	# ensure empty numeric values are 0
	if ($field =~ /^(can_upload|is_admin)$/ && !$value) {
		$value = 0;
	}

	return $value;
}

sub xdate {
	return Gruta::Data::format_date($_[0]->get('xdate'), $_[1]);
}

sub password {
	my $self	= shift;
	my $passwd	= shift;

	$self->set('password', Gruta::Data::crypt($passwd));

	return $self;
}


package Gruta::Data::Session;

use base 'Gruta::Data::BASE';

sub fields {
	return qw(id time user_id ip);
}

sub new {
	my $class = shift;

	my $sid = time() . $$;

	return $class->SUPER::new( id => $sid, time => time(), @_);
}


package Gruta::Data::Template;

use base 'Gruta::Data::BASE';

sub fields {
	return qw(id content);
}


package Gruta::Data::Comment;

use base 'Gruta::Data::BASE';

use Carp;

sub fields {
	return qw(id topic_id story_id ctime date approved author email content);
}


sub filter_field {
	my $self	= shift;
	my $field	= shift;
	my $value	= shift;

	if ($field eq 'approved' && !$value) {
		$value = 0;
	}

	return $value;
}


sub date {
	return Gruta::Data::format_date($_[0]->get('date'), $_[1]);
}

sub new {
	my $class = shift;

	my $id = sprintf("%08x%04x", time(), $$);

	return $class->SUPER::new(
        id      => $id,
        ctime   => time(),
        date    => Gruta::Data::today(),
        @_
    );
}


package Gruta::Data;

sub format_date {
	my $date	= shift;
	my $format	= shift;

	if (!$date) {
		return '';
	}

	if ($format) {
		use POSIX;
        my $ol;

		my ($y, $m, $d, $H, $M, $S) = ($date =~
			/^(\d{4})(\d{2})(\d{2})(\d{2})(\d{2})(\d{2})$/);

		# convert %y to %Y for compatibility
		$format =~ s/%y/%Y/g;

        # if %C_LOCALE is included in the format string,
        # set locale to C temporarily
        if ($format =~ s/%C_LOCALE//) {
            $ol = setlocale(LC_ALL, 'C');
        }

		$format = POSIX::strftime($format, $S, $M, $H,
					$d, $m - 1, $y - 1900);

        if ($ol) {
            setlocale(LC_ALL, $ol);
        }
	}
	else {
		$format = $date;
	}

	return $format;
}


$Gruta::Data::_today = undef;

sub today {
	my $format	= shift;

	my $date = $Gruta::Data::_today;

	if (!$date) {
		my ($S, $M, $H, $d, $m, $y) = (localtime)[0..5];

		$date = sprintf('%04d%02d%02d%02d%02d%02d',
			1900 + $y, $m + 1, $d, $H, $M, $S);

		$Gruta::Data::_today = $date;
	}

	return Gruta::Data::format_date($date, $format);
}


sub crypt {
	my $key		= shift;
	my $salt	= shift;

	# no salt? pick one at random
	if (!$salt) {
		$salt = sprintf('%02d', rand(100));
	}

	return crypt($key, $salt);
}

1;
