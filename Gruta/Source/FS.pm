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

	return $self;
}


sub delete {
	my $self	= shift;
	my $driver	= shift;

	$driver ||= $self->{_driver};

	unlink $driver->{path} . $self->_filename();

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

	open F, '>' . $driver->{path} . $filename
		or die "Can't write " . $filename;

	print F $self->get('content') || '';
	close F;

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

	mkdir $driver->{path} . $filename;

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


sub stories_by_date {
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
sub insert_story { $_[0]->_insert($_[1], 'Gruta::Data::FS::Story'); }
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
