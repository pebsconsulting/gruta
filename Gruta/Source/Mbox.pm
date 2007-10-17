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

sub tags {
	my $self	= shift;
	my @ret		= undef;
}

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
	my %h = ();
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
				$r->{id} =~ s/[^\d\w]/_/g;
			}
			elsif (/^Subject: (.+)$/i) {
				$r->{title} = $1;
			}
			elsif (/^Date: (.+)$/i) {
				$r->{date} = $self->_rfc822_to_gruta($1);
			}
			elsif (/^X-Format: (.+)$/i) {
				$r->{format} = $1;
			}
			elsif (/^Content-Type: .*text\/html/i and not $r->{format}) {
				$r->{format} = 'filtered_html';
			}
			elsif (/^$/) {
				$r->{offset} = tell(M);
				push(@s, $r);
				$h{$r->{id}} = $r;
				$r = undef;
			}
		}
	}

	close M;

	# store stories in reverse date order
	$self->{stories_l} = [ sort { $b->{date} <=> $a->{date} } @s ];
	$self->{stories_h} = { %h };

	return $self;
}


sub _save_index {
	my $self	= shift;

	open O, '>' . $self->{index_file} or
		die "Can't write '$self->{index_file}'";
	flock O, 2;

	foreach my $s (@{ $self->{stories_l} }) {
		print O join('|', $s->{id}, $s->{title},
			$s->{date}, $s->{offset}, $s->{format} || 'grutatxt'),
			"\n";
	}

	close O;

	return $self;
}


sub _load_index {
	my $self	= shift;

	open I, $self->{index_file} or
		die "Can't open '$self->{index_file}'";
	flock I, 1;

	my @s = ();
	my %h = ();

	while (<I>) {
		chomp;

		my $r = {};
		($r->{id}, $r->{title}, $r->{date}, $r->{offset}) =
			split(/\|/, $_);
		push(@s, $r);
		$h{$r->{id}} = $r;
	}

	$self->{stories_l} = [ @s ];
	$self->{stories_h} = { %h };

	close I;

	return $self;
}


sub _index {
	my $self	= shift;

	if (not -f $self->{index_file} or
		-M $self->{index_file} > -M $self->{file}) {
		$self->_build_index->_save_index();
	}
	else {
		$self->_load_index();
	}

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

	my $story = undef;

	if ($self->{topic_id} eq $topic_id) {
		if (my $s = $self->{stories_h}->{$id}) {

			# read the content
			open F, $self->{file} or
				die "Can't open '$self->{file}'";

			seek F, $s->{offset}, 0;
			my $c = '';

			while (<F>) {
				last if /^From /;
				$c .= $_;
			}

			close F;

			$story = Gruta::Data::Mbox::Story->new(
				id		=> $id,
				topic_id	=> $topic_id,
				title		=> $s->{title},
				date		=> $s->{date},
				format		=> $s->{format} || 'grutatxt',
				hits		=> 0,
				ctime		=> 0,
				userid		=> '',
				content		=> $c
			);
		}
	}

	return $story;
}

sub stories {
	my $self	= shift;
	my $topic_id	= shift;

	my @r = ();

	if ($self->{topic_id} eq $topic_id) {
		@r = keys(%{ $self->{stories_h} });
	}

	return @r;
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

sub stories_top_ten {
	my $self	= shift;
	my $num		= shift;

	return ();
}

sub stories_by_tag {
	my $self	= shift;
	my @tags	= shift;
}


sub tags {
	my $self	= shift;
}


sub new {
	my $class = shift;

	my $s = bless( { @_ }, $class);

	$s->_assert();

	my $n = 0;
	my %m = map { $_ => ++$n }
		qw(Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec);

	$s->{_month_hash} = { %m };

	$s->_index();

	return $s;
}

1;
