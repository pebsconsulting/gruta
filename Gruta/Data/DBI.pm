package Gruta::Data::DBI;

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


package Gruta::Data::DBI::Story;

sub new { my $class = shift; return bless( { @_ }, $class); }

sub id		{ $_[0]->{id}; }
sub topic	{ $_[0]->{topic}; }
sub title	{ $_[0]->{title}; }
sub date	{ $_[0]->{date}; }
sub user_id	{ $_[0]->{user_id}; }
sub format	{ $_[0]->{format}; }
sub hits	{ $_[0]->{hits}; }
sub ctime	{ $_[0]->{ctime}; }

package Gruta::Data::DBI::Topic;

sub new { my $class = shift; return bless( { @_ }, $class); }

package Gruta::Data::DBI::User;

sub new { my $class = shift; return bless( { @_ }, $class); }

package Gruta::Data::DBI;

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
		$t = Gruta::Data::DBI::Topic->new(
			id	=> $id,
			source	=> $self,
			%{ $r }
		);
	}

	return $t;
}


sub new {
	my $class = shift;

	my $s = bless( { @_ }, $class);

	$s->{dbh} = DBI->connect($s->{dbi_string},
		$s->{user}, $s->{passwd}, { RaiseError => 1 });

	return $s;
}

1;
