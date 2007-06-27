package Webon2::Driver::DBI;

use DBI;

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


package Webon2::Data::DBI::BASE;

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


sub insert {
	my $self	= shift;
	my $driver	= shift;

	my $sth;

	if (not $sth = $driver->{sth}->{insert}->{ref($self)}) {
		my $sql = 'INSERT INTO ' . $self->table() .
			' VALUES (' . join(', ', map { '?' } $self->fields()) . ')';

		$sth = $driver->{sth}->{insert}->{ref($self)} = $driver->_prepare($sql);
	}

	$driver->_execute($sth, map { $self->get($_) } $self->fields());

	return $self;
}


package Webon2::Data::DBI::Story;

use base 'Webon2::Data::Story';
use base 'Webon2::Data::DBI::BASE';

sub table { return 'stories'; }
sub pk { return qw(id topic_id); }

sub new_id {
	my $self	= shift;
	my $driver	= shift;
	my $prefix	= shift;

	my $id, $seq = 1;
	my $sth = $driver->_prepare('SELECT 1 FROM stories WHERE id = ? AND topic_id = ?');

	for(;;) {
		$id = $prefix . sprintf("%04d", $sql);

		$driver->_execute($sth, $id, $self->get('topic_id'));

		last unless $sth->fetchrow_array();
	}

	return $self->set('id', $id);
}

package Webon2::Data::DBI::Topic;

use base 'Webon2::Data::Topic';
use base 'Webon2::Data::DBI::BASE';

sub table { return 'topics'; }

package Webon2::Data::DBI::User;

use base 'Webon2::Data::User';
use base 'Webon2::Data::DBI::BASE';

sub table { return 'users'; }

package Webon2::Driver::DBI;

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


sub topic { return _one( @_, 'Webon2::Data::DBI::Topic' ); }
sub topics { return $_[0]->_all('topics'); }

sub user { return _one( @_, 'Webon2::Data::DBI::User' ); }
sub users { return $_[0]->_all('users'); }

sub story {
	my $self	= shift;
	my $topic_id	= shift;
	my $id		= shift;

	my $s = Webon2::Data::DBI::Story->new( topic_id => $topic_id, id => $id );
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


sub new {
	my $class = shift;

	my $s = bless( { @_ }, $class);

	$s->{dbh} = DBI->connect($s->{string},
		$s->{user}, $s->{passwd}, { RaiseError => 1 });

	return $s;
}

1;
