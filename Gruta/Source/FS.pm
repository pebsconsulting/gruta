package Gruta::Source::FS;

use Gruta::Data;

sub _load_metadata {
	my ($self, $file) = @_;
	my (%meta);

	if(open F, $self->{path} . $file) {
		while(<F>) {
			chop;

			if(/^([^:]*): (.*)$/) {
				$meta{$1} = $2;
			}
		}

		close F;
	}
	else {
		$meta{'_new'} = 1;
	}

	return(\%meta);
}


sub _save_metadata {
	my ($self, $file, $meta) = @_;

	open F, '>' . $self->{path} . $file or return(0);

	foreach my $key (keys(%$meta)) {
		print F "$key: $meta->{$key}\n" unless $key =~ /^_/;
	}

	close F;

	return(1);
}



package Gruta::Data::FS::BASE;

sub ext { return ''; }

sub _filename {
	my $self	= shift;

	return $self->base() . $self->get('id') . $self->ext();
}


sub load {
	my $self	= shift;
	my $driver	= shift;

	my $meta = undef;

	if (not $meta = $driver->_load_metadata($self->_filename())) {
		return undef;
	}

	foreach my $k ($self->fields()) {
		$self->set($k, $meta->{$k}) if $meta->{$k};
	}

	$self->{_driver} = $driver;

	return $self;
}

sub save {
	my $self	= shift;
	my $driver	= shift;

	$driver ||= $self->{_driver};

	$driver->_save_metadata( $self->_filename(), $self );

	return $self;
}


package Gruta::Data::FS::Story;

use base 'Gruta::Data::Story';
use base 'Gruta::Data::FS::BASE';

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
			push @ret, $id;
		}

		closedir D;
	}

	return @ret;
}

sub story {
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
