package Gruta::Source::FS;

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

		print F $f . ': ' . $self->get($k) . "\n";
	}

	close F;

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

	print F $self->get('content');
	close F;

}


package Gruta::Data::FS::Topic;

use base 'Gruta::Data::Topic';
use base 'Gruta::Data::FS::BASE';

sub base { return '/topics/'; }
sub ext { return '.META'; }

package Gruta::Data::FS::User;

use base 'Gruta::Data::User';
use base 'Gruta::Data::FS::BASE';

sub base { return '/users/'; }

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

sub stories_by_date {
}

sub insert_topic {
}

sub insert_user {
}

sub insert_story {
}


sub new {
	my $class = shift;

	my $s = bless( { @_ }, $class);

	$s->{path} ||= '.';

	return $s;
}

1;
