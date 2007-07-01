package Gruta::Source::DBI;

use DBI;
use Gruta::Data;

sub _prepare {
	my $self	= shift;
	my $sql		= shift;

	my $sth = $self->{dbh}->prepare($sql) or
		die $self->{dbh}->errstr;

	return $sth;
}

sub _execute {
	my $self	= shift;
	my $sth		= shift;

	return $sth->execute( @_ ) or die $self->{dbh}->errstr;
}


package Gruta::Data::DBI::BASE;

sub pk { return qw(id); }

sub load {
	my $self	= shift;
	my $driver	= shift;

	my $sth;

	if (not $sth = $driver->{sth}->{select}->{ref($self)}) {
		my $sql = 'SELECT ' . join(', ', $self->fields()) .
			' FROM ' . $self->table() .
			' WHERE ' . join(' AND ', map { "$_ = ?" } $self->pk());

		$sth = $driver->{sth}->{select}->{ref($self)} = $driver->_prepare($sql);
	}

	$driver->_execute($sth, map { $self->get($_) } $self->pk());

	my $r = $sth->fetchrow_hashref();

	if (not $r) {
		return undef;
	}

	foreach my $k ($self->fields()) {
		$self->set($k, $r->{$k});
	}

	$self->{_driver} = $driver;

	return $self;
}


sub save {
	my $self	= shift;
	my $driver	= shift;

	$driver ||= $self->{_driver};

	my $sth;

	if (not $sth = $driver->{sth}->{update}->{ref($self)}) {
		my $sql = 'UPDATE ' . $self->table() .
			' SET ' . join(', ', map { "$_ = ?" } $self->fields()) .
			' WHERE ' . join(' AND ', map { "$_ = ?" } $self->pk());

		$sth = $driver->{sth}->{update}->{ref($self)} = $driver->_prepare($sql);
	}

	$driver->_execute($sth,
		(map { $self->get($_) } $self->fields()),
		(map { $self->get($_) } $self->pk())
	);

	return $self;
}


package Gruta::Data::DBI::Story;

use base 'Gruta::Data::Story';
use base 'Gruta::Data::DBI::BASE';

sub table { return 'stories'; }
sub pk { return qw(id topic_id); }

package Gruta::Data::DBI::Topic;

use base 'Gruta::Data::Topic';
use base 'Gruta::Data::DBI::BASE';

sub table { return 'topics'; }

package Gruta::Data::DBI::User;

use base 'Gruta::Data::User';
use base 'Gruta::Data::DBI::BASE';

sub table { return 'users'; }

package Gruta::Source::DBI;

sub _all {
	my $self	= shift;
	my $table	= shift;

	my @ret = ();

	my $sth = $self->_prepare("SELECT id FROM $table");
	$self->_execute($sth);

	while(my @r = $sth->fetchrow_array()) {
		push(@ret, $r[0]);
	}

	return @ret;
}

sub _one {
	my $self	= shift;
	my $id		= shift;
	my $class	= shift;

	my $o = ${class}->new( id => $id );
	return $o->load( $self );
}


sub topic { return _one( @_, 'Gruta::Data::DBI::Topic' ); }
sub topics { return $_[0]->_all('topics'); }

sub user { return _one( @_, 'Gruta::Data::DBI::User' ); }
sub users { return $_[0]->_all('users'); }

sub story {
	my $self	= shift;
	my $topic_id	= shift;
	my $id		= shift;

	my $s = Gruta::Data::DBI::Story->new( topic_id => $topic_id, id => $id );
	return $s->load( $self );
}

sub stories_by_date {
	my $self	= shift;
	my $topic_id	= shift;
	my %args	= @_;

	$args{offset} += 0;
	$args{offset} = 0 if $args{offset} < 0;

	my @args = ( $topic_id );
	my $sql = 'SELECT id FROM stories WHERE topic_id = ?';

	if ($args{from}) {
		$sql .= ' AND date > ?';
		push(@args, $args{from});
	}

	if ($args{to}) {
		$sql .= ' AND date < ?';
		push(@args, $args{to});
	}

	if (!$args{future} && $args{today}) {
		$sql .= ' AND date < ?';
		push(@args, $args{today});
	}

	$sql .= ' ORDER BY date DESC';

	if ($args{num} || $args{offset}) {

		$sql .= ' LIMIT ?';
		push(@args, $args{num} || -1);

		if ($args{offset}) {
			$sql .= ' OFFSET ?';
			push(@args, $args{offset});
		}
	}

	my $sth = $self->_prepare($sql);
	$self->_execute($sth, @args);

	my @r = ();

	while(my $r = $sth->fetchrow_arrayref()) {
		push(@r, $r->[0]);
	}

	return @r;
}


sub _insert {
	my $self	= shift;
	my $obj		= shift;
	my $table	= shift;

	my $sth;

	if (not $sth = $self->{sth}->{insert}->{ref($obj)}) {
		my $sql = 'INSERT INTO ' . $table .
			' VALUES (' . join(', ', map { '?' } $obj->fields()) . ')';

		$sth = $self->{sth}->{insert}->{ref($obj)} = $self->_prepare($sql);
	}

	$self->_execute($sth, map { $obj->get($_) } $obj->fields());

	return $self;
}

sub insert_topic { $_[0]->_insert($_[1], 'topics'); }
sub insert_user { $_[0]->_insert($_[1], 'users'); }


sub insert_story {
	my $self	= shift;
	my $story	= shift;

	if (not $story->get('id')) {
		# alloc an id for the story
		my $id = time();

		my $sth = $self->_prepare(
			'SELECT 1 FROM stories WHERE topic_id = ? AND id = ?');

		do {
			$id++;
			$self->_execute($sth, $story->get('topic_id'), $id);
		} while ($sth->fetchrow_arrayref());

		$story->set('id', $id);
	}

	$self->_insert($story, 'stories');

	return $story;
}

sub new {
	my $class = shift;

	my $s = bless( { @_ }, $class);

	$s->{dbh} = DBI->connect($s->{string},
		$s->{user}, $s->{passwd}, { RaiseError => 1 });

	return $s;
}

1;
