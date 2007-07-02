package Gruta::Source::FS;

use Gruta::Data;

sub _load_metadata {
	my ($self, $file) = @_;
	my (%meta);

	$meta{_file} = $file;

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
	my ($self, $meta) = @_;

	open F, '>' . $self->{path} . $meta->{_file} or return(0);

	foreach my $key (keys(%$meta)) {
		print F "$key: $meta->{$key}\n" unless $key =~ /^_/;
	}

	close F;

	return(1);
}



package Gruta::Data::FS::BASE;

sub dummy {
}

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

sub topic { return $_[0]->_load_metadata('/topics/' . $_[1] . '.META'); }

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

	$s->{path} ||= '.';

	return $s;
}

1;
