package Gruta::Source::FS;

use Gruta::Data;

sub _load_metadata {
	my ($self, $obj, $suffix) = @_;
	my (%meta);

	$suffix = ".META" unless defined $suffix;

	$meta{'-obj-name'} = $obj;
	$meta{'-suffix'} = $suffix;

	if(open F, "${obj}${suffix}") {
		while(<F>) {
			chop;

			if(/^([^:]*): (.*)$/) {
				$meta{$1} = $2;
			}
		}

		close F;
	}
	else {
		$meta{'-new'} = 1;
	}

	return(\%meta);
}


sub _save_metadata {
	my ($self, $meta, $obj_name) = @_;

	# change object path, if defined
	$meta->{'-obj-name'} = $obj_name if $obj_name;

	open F, ">$meta->{'-obj-name'}$meta->{'-suffix'}" or return(0);

	foreach my $key (keys(%$meta)) {
		print F "$key: $meta->{$key}\n" unless $key =~ /^-/;
	}

	close F;

	return(1);
}



package Gruta::Data::FS::BASE;

package Gruta::Data::FS::Story;

use base 'Gruta::Data::Story';
use base 'Gruta::Data::FS::BASE';

package Gruta::Data::FS::Topic;

use base 'Gruta::Data::Topic';
use base 'Gruta::Data::FS::BASE';

package Gruta::Data::FS::User;

use base 'Gruta::Data::User';
use base 'Gruta::Data::FS::BASE';

package Gruta::Source::FS;

sub topic { return $_[0]->_load_metadata($_[1], ".META"); }

sub topics {
	my $self	= shift;

	my @ret = ();

	if (opendir D, $self->{topic_path}) {
		while (my $id = readdir D) {
			next unless -d $self->{topic_path} . '/' . $id;
			next -f $id =~ /^\./;

			push @ret, $id;
		}

		closedir D;
	}

	return @ret;
}

sub user {
}

sub users {
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

	$s->{topic_path} ||= $s->{path} . './topics';

	return $s;
}

1;
