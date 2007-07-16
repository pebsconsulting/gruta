package Gruta::Source::Mbox;

use strict;
use warnings;

use Gruta::Data;

sub _rfc822_to_gruta {
	# converts an RFC822-style Date to Gruta
	my $self	= shift;
	my $date	= shift;

	$date =~ s/^\w{3},\s+//;
	my ($d, $m, $y, $H, $M, $S) =
		($date =~ /(\d+)\s+(\w+)\s+(\d+)\s(\d+):(\d+):(\d+)/);

	return sprintf("%04d%02d%02d%02d%02d%02d",
		$y, $self->{_month_hash}->{$m}, $d, $H, $M, $S);
}


package Gruta::Data::Mbox::BASE;

sub dummy {
}

package Gruta::Data::Mbox::Story;

use base 'Gruta::Data::Story';
use base 'Gruta::Data::Mbox::BASE';

package Gruta::Data::Mbox::Topic;

use base 'Gruta::Data::Topic';
use base 'Gruta::Data::Mbox::BASE';

package Gruta::Source::Mbox;

sub _assert {
	my $self	= shift;

	$self->{file}		or die "Mandatory file";
	$self->{topic_id}	or die "Mandatory topic_id";
	$self->{topic_name}	or die "Mandatory topic_name";
	$self->{index_file}	or die "Mandatory index_file";

	return $self;
}

sub _build_index {
	my $self	= shift;

	open M, $self->{file} or
		die "Can't open '$self->{file}'";

	my @s = ();
	my $r = undef;

	while (<M>) {
		chomp;

		if (/^From / .. /^$/) {
			if (not $r) {
				$r = {};
			}

			# in header
			if (/^Message-ID: (.+)$/i) {
				$r->{id} = $1;
			}
			elsif (/^Subject: (.+)$/i) {
				$r->{title} = $1;
			}
			elsif (/^Date: (.+)$/i) {
				$r->{date} = $self->_rfc822_to_gruta($1);
			}
		}
		else {
			# in body
			if ($r) {
				$r->{body_offset} = tell(M);
				push(@s, $r);
				$r = undef;
			}
		}
	}

	close M;

	$self->{stories} = [ @s ];
	return $self;
}


sub topic {
	my $self	= shift;
	my $id		= shift;

	my $topic = undef;

	if ($self->{topic_id} eq $id) {
		$topic = Gruta::Data::Mbox::Topic->new(
			id		=> $id,
			name		=> $self->{topic_name},
			editors		=> '',
			internal	=> 0,
			max_stories	=> 0
		);
	}

	return $topic;
}

sub topics { return ($_[0]->{topic_id}) ; }

sub story {
	my $self	= shift;
	my $topic_id	= shift;
	my $id		= shift;
}

sub stories {
	my $self	= shift;
	my $topic_id	= shift;
}

sub stories_by_date {
	my $self	= shift;
	my $topic_id	= shift;
	my %args	= @_;
}

sub search_stories {
	my $self	= shift;
	my $topic_id	= shift;
	my $query	= shift;
}

sub new {
	my $class = shift;

	my $s = bless( { @_ }, $class);

	$s->_assert();

	my $n = 0;
	my %m = map { $_ => ++$n }
		qw(Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec);

	$s->{_month_hash} = { %m };

	$s->_build_index();

	return $s;
}

1;
