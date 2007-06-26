package Gruta::Data::DBI;

use DBI;

sub new {
	my $class = shift;

	my $s = bless( { @_ }, $class);

	$s->{dbh} = DBI->connect($s->{dbi_string},
		$s->{user}, $s->{passwd}, { RaiseError => 1 });

	return $s;
}

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


sub entry {
	my $self	= shift;
	my $topic	= shift;
	my $id		= shift;
}


sub topic {
	my $self	= shift;
	my $id		= shift;

	my $t		= undef;

	my $sth = $self->_prepare(
	'SELECT name, editors, max_stories, internal FROM topics WHERE id = ?');

	$self->_execute($sth, $id);

	if (my $r = $sth->fetchrow_hashref()) {
		$t = Webon2::Data::Topic->new(
			id	=> $id,
			source	=> $self,
			%{ $r }
		);
	}

	return $t;
}


1;
