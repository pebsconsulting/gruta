package Gruta::Source::FS;

use strict;
use warnings;

use Gruta::Data;

package Gruta::Data::FS::BASE;

use Carp;

sub ext { return '.META'; }

sub _filename {
	my $self	= shift;

	$self->_assert();
	$self->source->_assert();

	return $self->source->{path} . $self->base() .
		$self->get('id') . $self->ext();
}


sub load {
	my $self	= shift;
	my $driver	= shift;

	$self->source( $driver );

	if (not open F, $self->_filename()) {
		return undef;
	}

	while (<F>) {
		chop;

		if(/^([^:]*): (.*)$/) {
			my ($key, $value) = ($1, $2);

			$key =~ s/-/_/g;

			if (grep (/^$key$/, $self->fields())) {
				$self->set($key, $value);
			}
		}
	}

	close F;

	return $self;
}

sub save {
	my $self	= shift;
	my $driver	= shift;

	$self->source( $driver ) if $driver;

	my $filename = $self->_filename();

	open F, '>' . $filename or croak "Can't write " . $filename . ': ' . $!;

	foreach my $k ($self->fields()) {
		my $f = $k;

		$f =~ s/_/-/g;

		print F $f . ': ' . ($self->get($k) || '') . "\n";
	}

	close F;

	return $self;
}


sub delete {
	my $self	= shift;
	my $driver	= shift;

	$self->source( $driver ) if $driver;

	unlink $self->_filename();

	return $self;
}

package Gruta::Data::FS::Story;

use base 'Gruta::Data::Story';
use base 'Gruta::Data::FS::BASE';

use Carp;

sub base { return Gruta::Data::FS::Topic::base() . $_[0]->get('topic_id') . '/'; }

sub fields { grep !/(content|topic_id)/, $_[0]->SUPER::fields(); }
sub vfields { return ($_[0]->SUPER::vfields(), 'content', 'topic_id'); }

sub _destroy_index {
	my $self	= shift;

	my $filename = $self->_filename();

	# destroy the topic index, to be rewritten
	# in the future by _topic_index()
	$filename =~ s!/[^/]+$!/.INDEX!;
	unlink $filename;
}

sub save {
	my $self	= shift;
	my $driver	= shift;

	$self->SUPER::save( $driver );

	my $filename = $self->_filename();
	$filename =~ s/\.META$//;

	open F, '>' . $filename or croak "Can't write " . $filename . ': ' . $!;

	print F $self->get('content') || '';
	close F;

	$self->_destroy_index();

	return $self;
}

sub touch {
	my $self = shift;

	my $hits = $self->get('hits') + 1;

	$self->set('hits', $hits);

	# call $self->SUPER::save() instead of $self->save()
	# to avoid saving content (unnecessary) and deleting
	# the topic INDEX (even probably dangerous)
	$self->SUPER::save();

	$self->source->_update_top_ten($hits, $self->get('topic_id'),
		$self->get('id'));

	return $self;
}

sub tags {
	my $self	= shift;
	my @ret		= ();

	my $filename = $self->_filename();
	$filename =~ s/\.META$/.TAGS/;

	if (scalar(@_)) {
		if (open F, '>' . $filename) {
			print F join(', ', map { s/^\s+//; s/\s+$//; lc($_) } @_), "\n";
			close F;
		}
	}
	else {
		if (open F, $filename) {
			my $l = <F>;
			close F;

			chomp($l);
			@ret = split(/\s*,\s*/, $l);
		}
	}

	return @ret;
}

sub delete {
	my $self	= shift;
	my $driver	= shift;

	my $file = $self->_filename();

	$self->SUPER::delete($driver);

	# also delete content and TAGS
	$file =~ s/\.META$//;

	unlink $file;
	unlink $file . '.TAGS';

	$self->_destroy_index();

	return $self;
}


package Gruta::Data::FS::Topic;

use base 'Gruta::Data::Topic';
use base 'Gruta::Data::FS::BASE';

sub base { return '/topics/'; }

sub save {
	my $self	= shift;
	my $driver	= shift;

	$self->SUPER::save( $driver );

	my $filename = $self->_filename();
	$filename =~ s/\.META$//;

	mkdir $filename;

	return $self;
}

package Gruta::Data::FS::User;

use base 'Gruta::Data::User';
use base 'Gruta::Data::FS::BASE';

sub ext { return ''; }
sub base { return '/users/'; }

package Gruta::Data::FS::Session;

use base 'Gruta::Data::Session';
use base 'Gruta::Data::FS::BASE';

sub ext { return ''; }
sub base { return '/sids/'; }

package Gruta::Source::FS;

use Carp;

sub _assert {
	my $self	= shift;

	$self->{path} or croak "Invalid path";

	return $self;
}

sub _one {
	my $self	= shift;
	my $id		= shift;
	my $class	= shift;

	my $o = ${class}->new( id => $id );
	$o->load( $self );
}

sub topic { return _one( @_, 'Gruta::Data::FS::Topic' ); }

sub topics {
	my $self	= shift;

	my @ret = ();

	my $path = $self->{path} . Gruta::Data::FS::Topic::base();

	if (opendir D, $path) {
		while (my $id = readdir D) {
			next unless -d $path . $id;
			next if $id =~ /^\./;

			push @ret, $id;
		}

		closedir D;
	}

	return @ret;
}

sub user { return _one( @_, 'Gruta::Data::FS::User' ); }

sub users {
	my $self	= shift;

	my @ret = ();

	my $path = $self->{path} . Gruta::Data::FS::User::base();

	if (opendir D, $path) {
		while (my $id = readdir D) {
			next if -d $path . $id;
			push @ret, $id;
		}

		closedir D;
	}

	return @ret;
}

sub story {
	my $self	= shift;
	my $topic_id	= shift;
	my $id		= shift;

	my $story = Gruta::Data::FS::Story->new( topic_id => $topic_id, id => $id );
	if (not $story->load( $self )) {

		$story = Gruta::Data::FS::Story->new( topic_id => $topic_id . '-arch',
			id => $id );

		if (not $story->load( $self )) {
			return undef;
		}
	}

	# now load the content
	my $file = $story->_filename();
	$file =~ s/\.META$//;

	open F, $file or croak "Can't open $file content: $!";

	$story->set('content', join('', <F>));
	close F;

	return $story;
}

sub stories {
	my $self	= shift;
	my $topic_id	= shift;

	my @ret = ();

	my $path = $self->{path} . Gruta::Data::FS::Topic::base() . $topic_id;

	if (opendir D, $path) {
		while (my $id = readdir D) {
			if ($id =~ s/\.META$//) {
				push(@ret, $id);
			}
		}

		closedir D;
	}
	
	return @ret;
}


sub _topic_index {
	my $self	= shift;
	my $topic_id	= shift;

	my $index = $self->{path} . Gruta::Data::FS::Topic::base() . $topic_id;

	if (! -d $index) {
		return undef;
	}

	$index .= '/.INDEX';

	if (not open I, $index) {

		my @i = ();
		foreach my $id ($self->stories($topic_id)) {
			my $story = $self->story($topic_id, $id);

			push(@i, $story->get('date') . ':' . $id);
		}

		open I, '>' . $index or croak "Can't create INDEX for $topic_id: $!";
		flock I, 2;

		foreach my $l (reverse(sort(@i))) {
			print I $l, "\n";
		}
	}

	close I;

	return $index;
}


sub _update_top_ten {
	my $self	= shift;
	my $hits	= shift;
	my $topic_id	= shift;
	my $id		= shift;

	my $index = $self->{path} . Gruta::Data::FS::Topic::base() . '/.top_ten';

	my $u = 0;
	my @l = ();

	if (open F, $index) {
		flock F, 1;
		while (my $l = <F>) {
			chomp($l);

			my ($h, $t, $i) = split(':', $l);

			if ($u == 0 && $h < $hits) {
				$u = 1;
				push(@l, "$hits:$topic_id:$id");
			}

			if ($t ne $topic_id or $i ne $id) {
				push(@l, $l);
			}
		}

		close F;
	}

	if ($u == 0 && scalar(@l) < 100) {
		$u = 1;
		push(@l, "$hits:$topic_id:$id");
	}

	if ($u) {
		if (open F, '>' . $index) {
			flock F, 2;
			my $n = 0;

			foreach my $l (@l) {
				print F $l, "\n";

				if (++$n == 100) {
					last;
				}
			}

			close F;
		}
	}

	return undef;
}


sub stories_by_date {
	my $self	= shift;
	my $topics	= shift;
	my %args	= @_;

	my @topics;

	if (!$topics) {
		@topics = $self->topics();
	}
	else {
		@topics = @{ $topics };
	}

	$args{offset} += 0;
	$args{offset} = 0 if $args{offset} < 0;

	my @R = ();

	foreach my $topic_id (@topics) {
		my $i = $self->_topic_index($topic_id) or next;
		open I, $i or next;
		flock I, 1;

		my @r = ();
		my $o = 0;

		while(<I>) {
			chomp;

			my ($date, $id) = (/^(\d*):(.*)$/);

			# skip future stories
			next if not $args{future} and $date gt Gruta::Data::today();

			# skip if date is above the threshold
			next if $args{'to'} and $date gt $args{'to'};

			# exit if date is below the threshold
			last if $args{'from'} and $date lt $args{'from'};

			# skip offset stories
			next if $args{'offset'} and ++$o <= $args{'offset'};

			push(@r, [ $id, $topic_id, $date ]);

			# exit if we have all we need
			last if $args{'num'} and $args{'num'} == scalar(@r);
		}

		close I;

		@R = ( @r, @R );
	}

	return @R;
}

sub search_stories {
	my $self	= shift;
	my $topic_id	= shift;
	my $query	= shift;
	my $future	= shift;

	my @q = split(/\s+/,$query);

	my @r = ();

	foreach my $id ($self->stories_by_date( [ $topic_id ], future => $future )) {

		my $story = $self->story($topic_id, $id->[0]);
		my $content = $story->get('content');
		my $found = 0;

		# try complete query first
		if($content =~ /\b$query\b/i) {
			$found = scalar(@q);
		}
		else {
			# try separate words
			foreach my $q (@q) {
				if(length($q) > 1 and $content =~ /\b$q\b/i) {
					$found++;
				}
			}
		}

		push(@r, $id->[0]) if $found == scalar(@q);
	}

	return @r;
}

sub stories_top_ten {
	my $self	= shift;
	my $num		= shift;

	my @r = ();

	my $index = $self->{path} . Gruta::Data::FS::Topic::base() . '/.top_ten';

	if (open F, $index) {
		flock F, 1;

		while (defined(my $l = <F>) and $num--) {
			chomp($l);
			push(@r, [ split(':', $l) ]);
		}

		close F;
	}

	return @r;
}


sub _collect_tags {
	my $self = shift;

	my @ret = ();

	foreach my $topic_id ($self->topics()) {

		my $topic = $self->topic($topic_id);

		my $files = $topic->_filename();
		$files =~ s/\.META$/\/*.TAGS/;

		my @ls = glob($files);

		foreach my $f (@ls) {
			if (open F, $f) {
				my $tags = <F>;
				chomp $tags;
				close F;

				my ($id) = ($f =~ m{/([^/]+)\.TAGS});

				push(@ret,
					[ $topic_id, $id, [ split(/\s*,\s*/, $tags) ] ]
				);
			}
		}
	}

	return @ret;
}


sub search_stories_by_tag {
	my $self	= shift;
	my $tag		= shift;
	my $future	= shift;

	my @tags	= map { lc($_) } split(/\s*,\s*/, $tag);

	my @ret = ();

	foreach my $tr ($self->_collect_tags()) {

		my @ts = @{$tr->[2]};

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
				my $story = $self->story($tr->[0], $tr->[1]);

				if ($story->get('date') > Gruta::Data::today()) {
					next;
				}
			}

			push(@ret, [ $tr->[0], $tr->[1] ]);
		}
	}

	return @ret;
}


sub tags {
	my $self	= shift;

	my @ret = ();
	my %h = ();

	foreach my $tr ($self->_collect_tags()) {

		foreach my $t (@{$tr->[2]}) {
			$h{$t}++;
		}
	}

	foreach my $k (keys(%h)) {
		push(@ret, [ $k, $h{$k} ]);
	}

	return @ret;
}


sub session { return _one( @_, 'Gruta::Data::FS::Session' ); }

sub purge_old_sessions {
	my $self	 = shift;

	my $path = $self->{path} . Gruta::Data::FS::Session::base();

	if (opendir D, $path) {
		while(my $s = readdir D) {
			my $f = $path . $s;

			next if -d $f;

			if (-M $f > 1) {
				unlink $f;
			}
		}

		closedir D;
	}

	return undef;
}


sub _insert {
	my $self	= shift;
	my $obj		= shift;
	my $class	= shift;

	bless($obj, $class);
	$obj->save( $self );

	return $obj;
}

sub insert_topic { $_[0]->_insert($_[1], 'Gruta::Data::FS::Topic'); }
sub insert_user { $_[0]->_insert($_[1], 'Gruta::Data::FS::User'); }

sub insert_story {
	my $self	= shift;
	my $story	= shift;

	if (not $story->get('id')) {
		# alloc an id for the story
		my $id = undef;

		do {
			$id = $story->new_id();

		} while $self->story($story->get('topic_id'), $id);

		$story->set('id', $id);
	}

	$self->_insert($story, 'Gruta::Data::FS::Story');
	return $story;
}

sub insert_session { $_[0]->_insert($_[1], 'Gruta::Data::FS::Session'); }


sub create {
	my $self	= shift;

	my @l = map { $self->{path} . $_ } (
		Gruta::Data::FS::Topic::base(),
		Gruta::Data::FS::User::base(),
		Gruta::Data::FS::Session::base()
	);

	foreach my $d (@l) {
		if (! -d $d) {
			mkdir $d, 0755 or die "Cannot mkdir $d";
		}
	}

	return $self;
}


sub new {
	my $class = shift;

	my $s = bless( { @_ }, $class);

	$s->_assert();

	$s->create();

	return $s;
}

1;
