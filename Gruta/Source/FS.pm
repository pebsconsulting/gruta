package Gruta::Source::FS;

use strict;
use warnings;

use Gruta::Data;

package Gruta::Data::FS::BASE;

sub ext { return ''; }

sub _filename {
	my $self	= shift;

	return $self->base() . $self->get('id') . $self->ext();
}


sub load {
	my $self	= shift;
	my $driver	= shift;

	if (not open F, $driver->{path} . $self->_filename()) {
		return undef;
	}

	while (<F>) {
		chop;

		if(/^([^:]*): (.*)$/) {
			my ($key, $value) = ($1, $2);

			$key =~ s/-/_/g;

			if (grep ($key, $self->fields())) {
				$self->set($key, $value);
			}
		}
	}

	close F;

	$self->{_driver} = $driver;

	return $self;
}

sub save {
	my $self	= shift;
	my $driver	= shift;

	$driver ||= $self->{_driver};

	my $filename = $self->_filename();

	open F, '>' . $driver->{path} . $filename
		or die "Can't write " . $filename;

	foreach my $k ($self->fields()) {
		my $f = $k;

		$f =~ s/_/-/g;

		print F $f . ': ' . ($self->get($k) || '') . "\n";
	}

	close F;

	$self->{_driver} = $driver;

	return $self;
}


sub delete {
	my $self	= shift;
	my $driver	= shift;

	$driver ||= $self->{_driver};

	unlink $driver->{path} . $self->_filename();

	$self->{_driver} = $driver;

	return $self;
}

package Gruta::Data::FS::Story;

use base 'Gruta::Data::Story';
use base 'Gruta::Data::FS::BASE';

sub base { return '/topics/' . $_[0]->get('topic_id') . '/'; }
sub ext { return '.META'; }

sub fields { grep !/content/, $_[0]->SUPER::fields(); }
sub vfields { return ($_[0]->SUPER::vfields(), 'content'); }

sub save {
	my $self	= shift;
	my $driver	= shift;

	$self->SUPER::save( $driver );

	my $filename = $self->_filename();
	$filename =~ s/\.META$//;

	open F, '>' . $self->{_driver}->{path} . $filename
		or die "Can't write " . $filename;

	print F $self->get('content') || '';
	close F;

	# destroy the topic index, to be rewritten
	# in the future by _topic_index()
	unlink $self->{_driver}->{path} . '/topics/' .
		$self->get('topic_id') . '/.INDEX';

	return $self;
}


package Gruta::Data::FS::Topic;

use base 'Gruta::Data::Topic';
use base 'Gruta::Data::FS::BASE';

sub base { return '/topics/'; }
sub ext { return '.META'; }

sub save {
	my $self	= shift;
	my $driver	= shift;

	$self->SUPER::save( $driver );

	my $filename = $self->_filename();
	$filename =~ s/\.META$//;

	mkdir $self->{_driver}->{path} . $filename;

	return $self;
}

package Gruta::Data::FS::User;

use base 'Gruta::Data::User';
use base 'Gruta::Data::FS::BASE';

sub base { return '/users/'; }

package Gruta::Data::FS::Session;

use base 'Gruta::Data::Session';
use base 'Gruta::Data::FS::BASE';

sub base { return '/sids/'; }

package Gruta::Source::FS;

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

	if (opendir D, $self->{path} . '/topics') {
		while (my $id = readdir D) {
			next unless -d $self->{path} . '/topics/' . $id;
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

	if (opendir D, $self->{path} . '/users') {
		while (my $id = readdir D) {
			next if -d $self->{path} . '/users/' . $id;
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

	open F, $self->{path} . $file or
		die "Can't open $file content";

	$story->set('content', join('', <F>));
	close F;

	return $story;
}

sub stories {
	my $self	= shift;
	my $topic_id	= shift;

	my @ret = ();

	if (opendir D, $self->{path} . '/topics/' . $topic_id) {
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

	my $index = $self->{path} . '/topics/' . $topic_id . '/.INDEX';

	if (not open I, $index) {

		my @i = ();
		foreach my $id ($self->stories($topic_id)) {
			my $story = $self->story($topic_id, $id);

			push(@i, $story->get('date') . ':' . $id);
		}

		open I, '>' . $index or die "Can't create INDEX for $topic_id";
		flock I, 2;

		foreach my $l (reverse(sort(@i))) {
			print I $l, "\n";
		}
	}

	close I;

	return $index;
}


sub stories_by_date {
	my $self	= shift;
	my $topic_id	= shift;
	my %args	= @_;

	$args{offset} += 0;
	$args{offset} = 0 if $args{offset} < 0;

	open I, $self->_topic_index($topic_id);
	flock I, 1;

	my @r = ();
	my $o = 0;

	while(<I>) {
		chomp;

		my ($date, $id) = (/^(\d*):(.*)$/);

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

		push(@r, $id);

		# exit if we have all we need
		last if $args{'num'} and $args{'num'} == scalar(@r);
	}

	close I;

	return @r;
}

sub search_stories {
	my $self	= shift;
	my $topic_id	= shift;
	my $query	= shift;

	my @q = split(/\s+/,$query);

	my @r = ();

	foreach my $id ($self->stories_by_date( $topic_id )) {

		my $story = $self->story($topic_id, $id);
		my $content = $story->get('content');
		my $found = 0;

		# try complete query first
		if($content =~ /\b$query\b/i) {
			$found = 1;
		}
		else {
			# try separate words
			foreach my $q (@q) {
				if(length($q) > 1 and $content =~ /\b$q\b/i) {
					$found = 1;
					last;
				}
			}
		}

		push(@r, $id) if $found;
	}

	return @r;
}

sub session { return _one( @_, 'Gruta::Data::FS::Session' ); }

sub purge_old_sessions {
	my $self	 = shift;

	if (opendir D, $self->{path} . '/sids/') {
		while(my $s = readdir D) {
			my $f = $self->{path} . '/sids/' . $s;

			next if -d $f;

			if (-M $f) {
				unlink $f;
			}
		}

		closedir D;
	}
}


sub _insert {
	my $self	= shift;
	my $obj		= shift;
	my $class	= shift;

	bless($obj, $class);
	$obj->save( $self );
}

sub insert_topic { $_[0]->_insert($_[1], 'Gruta::Data::FS::Topic'); }
sub insert_user { $_[0]->_insert($_[1], 'Gruta::Data::FS::User'); }

sub insert_story {
	my $self	= shift;
	my $story	= shift;

	if (not $story->get('id')) {
		# alloc an id for the story
		my $id = time();

		while (-f $self->{path} . '/topics/' .
			$story->get('topic_id') . '/' . $id) {
			$id++;
		}

		$story->set('id', $id);
	}

	$self->_insert($story, 'Gruta::Data::FS::Story');
}

sub insert_session { $_[0]->_insert($_[1], 'Gruta::Data::FS::Session'); }


sub create {
	my $self	= shift;

	mkdir $self->{path}, 0755;
	mkdir $self->{path} . '/topics', 0755;
	mkdir $self->{path} . '/users', 0755;
	mkdir $self->{path} . '/sids', 0755;
}


sub new {
	my $class = shift;

	my $s = bless( { @_ }, $class);

	$s->{path} ||= '.';

	return $s;
}

1;
