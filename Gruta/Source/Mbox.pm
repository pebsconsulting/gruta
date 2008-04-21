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

use Carp;

use base 'Gruta::Data::Story';
use base 'Gruta::Data::Mbox::BASE';

sub load {
	my $self	= shift;
	my $driver	= shift;

	$driver = $self->source( $driver );

	if (my $s = $driver->{stories_h}->{$self->get('id')}) {

		# read the content
		open F, $driver->{file} or
			croak "Can't open '$driver->{file}'";

		seek F, $s->{offset}, 0;
		my $c = '';

		while (<F>) {
			last if /^From /;
			$c .= $_;
		}

		close F;

		$self->set('title',	$s->{title});
		$self->set('date',	$s->{date});
		$self->set('format',	$s->{format} || 'grutatxt');
		$self->set('hits',	0);
		$self->set('ctime',	0);
		$self->set('userid',	'');
		$self->set('content',	$c);
	}

	return $self;
}

sub tags {
	my $self	= shift;
	my @ret		= ();

	unless (scalar(@_)) {
		# get tags from the index
		my $s = $self->source->{stories_h}->{$self->get('id')};

		@ret = split(/\s*,\s*/, $s->{tags});
	}

	return @ret;
}

package Gruta::Data::Mbox::Topic;

use base 'Gruta::Data::Topic';
use base 'Gruta::Data::Mbox::BASE';

package Gruta::Source::Mbox;

use Carp;

sub _assert {
	my $self	= shift;

	$self->{file}		or croak "Mandatory file";
	$self->{topic_id}	or croak "Mandatory topic_id";
	$self->{topic_name}	or croak "Mandatory topic_name";
	$self->{index_file}	or croak "Mandatory index_file";

	return $self;
}

sub _build_index {
	my $self	= shift;

	open M, $self->{file} or
		croak "Can't open '$self->{file}'";

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
			if (/^Message-ID:\s*(.+)$/i) {
				use Digest::MD5;

				my $md5 = Digest::MD5->new();
				$md5->add($1);

				$r->{id} = $md5->hexdigest();
			}
			elsif (/^Subject:\s*(.+)$/i) {
				$r->{title} = $1;
			}
			elsif (/^Date:\s*(.+)$/i) {
				$r->{date} = $self->_rfc822_to_gruta($1);
			}
			elsif (/^X-Format:\s*(.+)$/i) {
				$r->{format} = $1;
			}
			elsif (/^Content-Type:\s*.*text\/html/i and not $r->{format}) {
				$r->{format} = 'filtered_html';
			}
			elsif (/^X-Tags:\s*(.+)$/i || /^Keywords:\s*(.+)$/i) {
				$r->{tags} = $1;
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
		croak "Can't write '$self->{index_file}'";
	flock O, 2;

	foreach my $s (@{ $self->{stories_l} }) {
		print O join('|', $s->{id}, $s->{title},
			$s->{date}, $s->{offset},
			$s->{format} || 'grutatxt', $s->{tags} || ''),
			"\n";
	}

	close O;

	return $self;
}


sub _load_index {
	my $self	= shift;

	open I, $self->{index_file} or
		croak "Can't open '$self->{index_file}'";
	flock I, 1;

	my @s = ();
	my %h = ();

	while (<I>) {
		chomp;

		my $r = {};
		($r->{id}, $r->{title}, $r->{date},
			$r->{offset}, $r->{format}, $r->{tags}) =
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

		$story = Gruta::Data::Mbox::Story->new (
			id => $id, topic_id => $topic_id )->load($self);
	}

	return $story;
}

sub stories {
	my $self	= shift;
	my $topic_id	= shift;

	my @r = ();

	if ($self->{topic_id} eq $topic_id) {
		@r = map { $_->{id} } @{ $self->{stories_l} };
	}

	return @r;
}


sub stories_by_date {
	my $self	= shift;
	my $topics	= shift;
	my %args	= @_;

	my $topic_id;

	if (!$topics) {
		$topic_id = $self->{topic_id};
	}
	else {
		$topic_id = $topics->[0];
	}

	$args{offset} += 0;
	$args{offset} = 0 if $args{offset} < 0;

	my @r = ();
	my $o = 0;

	if ($self->{topic_id} eq $topic_id) {
		foreach my $s (@{ $self->{stories_l} }) {
			my $date = $s->{date};

			# skip future stories
			next if not $args{future} and
				$args{today} and
				$date > $args{today};

			# skip if date is above the threshold
			next if $args{'to'} and $date > $args{'to'};

			# exit if date is below the threshold
			last if $args{'from'} and $date < $args{'from'};

			# skip offset stories
			next if $args{'offset'} and ++$o <= $args{'offset'};

			push(@r, [ $s->{id}, $topic_id, $date ]);

			# exit if we have all we need
			last if $args{'num'} and $args{'num'} == scalar(@r);
		}
	}

	return @r;
}

sub search_stories {
	my $self	= shift;
	my $topic_id	= shift;
	my $query	= shift;

	return ();
}

sub stories_top_ten {
	my $self	= shift;
	my $num		= shift;

	# as no hit counts are maintained, return empty

	return ();
}

sub stories_by_tag {
	my $self	= shift;
	my $topics	= shift;
	my $tag		= shift;
	my $future	= shift;

	my $topic_id;

	if (!$topics) {
		$topic_id = $self->{topic_id};
	}
	else {
		$topic_id = $topics->[0];
	}

	# not this topic? return
	if ($self->{topic_id} ne $topic_id) {
		return ();
	}

	my @tags = map { lc($_) } split(/\s*,\s*/, $tag);
	my @ret = ();

	foreach my $e (@{$self->{stories_l}}) {
		my @ts = split(/\s*,\s*/, $e->{tags});

		# skip stories with less tags than the wanted ones
		if (scalar(@ts) < scalar(@tags)) {
			next;
		}

		# count matches
		my $c = 0;

		foreach my $t (@ts) {
			if (grep(/^$t$/, @tags)) {
				$c++;
			}
		}

		if ($c >= scalar(@tags)) {

			# if no future stories are wanted, discard them
			if (!$future) {
				if ($e->{date} > Gruta::Data::today()) {
					next;
				}
			}

			push(@ret, [ $topic_id, $e->{id} ]);
		}
	}

	return @ret;
}


sub tags {
	my $self	= shift;

	my @ret = ();
	my %h = ();

	foreach my $e (@{$self->{stories_l}}) {
		my $tags = $e->{tags};

		foreach my $t (split(/\s*,\s*/, $tags)) {
			$h{$t}++;
		}
	}

	foreach my $k (keys(%h)) {
		push(@ret, [ $k, $h{$k} ]);
	}

	return @ret;
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
