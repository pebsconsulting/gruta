package Gruta::Source::DBI;

use base 'Gruta::Source::BASE';

use strict;
use warnings;
use Carp;

use DBI;
use Gruta::Data;

my $schema_version = 9;

sub _prepare {
	my $self	= shift;
	my $sql		= shift;

	my $sth = $self->{dbh}->prepare($sql) or
		croak $self->{dbh}->errstr;

	return $sth;
}

sub _execute {
	my $self	= shift;
	my $sth		= shift;

	return $sth->execute( @_ ) or croak $self->{dbh}->errstr;
}


package Gruta::Data::DBI::BASE;

sub pk {
	return qw(id);
}

sub load {
	my $self	= shift;
	my $driver	= shift;

	$self->source( $driver );

	my $sth;

	if (not $sth = $self->source->{sth}->{select}->{ref($self)}) {
		my $sql = 'SELECT ' . join(', ', $self->fields()) .
			' FROM ' . $self->table() .
			' WHERE ' . join(' AND ', map { "$_ = ?" } $self->pk());

		$sth = $self->source->{sth}->{select}->{ref($self)} =
			$self->source->_prepare($sql);
	}

	$self->source->_execute($sth, map { $self->get($_) } $self->pk());

	my $r = $sth->fetchrow_hashref();

	if (not $r) {
		return undef;
	}

	foreach my $k ($self->fields()) {
		$self->set($k, $r->{$k});
	}

	return $self;
}


sub save {
	my $self	= shift;
	my $driver	= shift;

	$self->source( $driver ) if $driver;

	my $sth;

	if (not $sth = $self->source->{sth}->{update}->{ref($self)}) {
		my $sql = 'UPDATE ' . $self->table() .
			' SET ' . join(', ', map { "$_ = ?" } $self->fields()) .
			' WHERE ' . join(' AND ', map { "$_ = ?" } $self->pk());

		$sth = $self->source->{sth}->{update}->{ref($self)} =
			$self->source->_prepare($sql);
	}

	$self->source->_execute($sth,
		(map { $self->get($_) } $self->fields()),
		(map { $self->get($_) } $self->pk())
	);

	return $self;
}


sub delete {
	my $self	= shift;
	my $driver	= shift;

	$self->source( $driver ) if $driver;

	my $sth;

	if (not $sth = $self->source->{sth}->{delete}->{ref($self)}) {
		my $sql = 'DELETE FROM ' . $self->table() .
			' WHERE ' . join(' AND ', map { "$_ = ?" } $self->pk());

		$sth = $self->source->{sth}->{delete}->{ref($self)} =
			$self->source->_prepare($sql);
	}

	$self->source->_execute($sth,
		(map { $self->get($_) } $self->pk())
	);

	return $self;
}


package Gruta::Data::DBI::Story;

use base 'Gruta::Data::Story';
use base 'Gruta::Data::DBI::BASE';

sub table {
	return 'stories';
}

sub pk {
	return qw(id topic_id);
}

sub touch {
	my $self = shift;

	if (! $self->source->dummy_touch()) {
		my $sth = $self->source->_prepare(
			'UPDATE stories SET hits = hits + 1 WHERE topic_id = ? AND id = ?');
		$self->source->_execute($sth, $self->get('topic_id'), $self->get('id'));
	}

	return $self;
}

sub tags {
	my $self	= shift;
	my @ret		= ();

	if (scalar(@_)) {
		my @tags = @_;

		# first, delete all tags for this story
		my $sth = $self->source->_prepare(
			'DELETE FROM tags WHERE topic_id = ? AND id = ?');
		$self->source->_execute($sth, $self->get('topic_id'), $self->get('id'));

		# second, add all the new ones
		$sth = $self->source->_prepare(
			'INSERT INTO tags (id, topic_id, tag) VALUES (?, ?, ?)');

		foreach my $t (@tags) {
			$t =~ s/^\s+//;
			$t =~ s/\s+$//;

			$self->source->_execute($sth,
				$self->get('id'),
				$self->get('topic_id'),
				lc($t) );
		}
	}
	else {
		# read from database
		my $sth = $self->source->_prepare(
			'SELECT tag FROM tags WHERE topic_id = ? AND id = ?');
		$self->source->_execute($sth, $self->get('topic_id'), $self->get('id'));

		while (my $r = $sth->fetchrow_arrayref()) {
			push(@ret, $r->[0]);
		}
	}

	return @ret;
}

package Gruta::Data::DBI::Topic;

use base 'Gruta::Data::Topic';
use base 'Gruta::Data::DBI::BASE';

sub table {
	return 'topics';
}

package Gruta::Data::DBI::User;

use base 'Gruta::Data::User';
use base 'Gruta::Data::DBI::BASE';

sub table {
	return 'users';
}

package Gruta::Data::DBI::Session;

use base 'Gruta::Data::Session';
use base 'Gruta::Data::DBI::BASE';

sub table {
	return 'sids';
}

package Gruta::Data::DBI::Template;

use base 'Gruta::Data::Template';
use base 'Gruta::Data::DBI::BASE';

sub table {
	return 'templates';
}

package Gruta::Data::DBI::Comment;

use base 'Gruta::Data::Comment';
use base 'Gruta::Data::DBI::BASE';

sub table {
	return 'comments';
}

sub approve {
	my $self = shift;

	my $sth = $self->source->_prepare(
		'UPDATE comments SET approved = 1 WHERE topic_id = ? AND ' .
		'story_id = ? AND id = ?');

	$self->source->_execute($sth,
						$self->get('topic_id'),
						$self->get('story_id'),
						$self->get('id')
					);

	return $self;
}

package Gruta::Source::DBI;

sub _assert {
	return $_[0];
}

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


sub topic {
	return _one( @_, 'Gruta::Data::DBI::Topic' );
}

sub topics {
	return $_[0]->_all('topics');
}

sub user {
	return _one( @_, 'Gruta::Data::DBI::User' );
}

sub users {
	return $_[0]->_all('users');
}

sub template {
	return _one( @_, 'Gruta::Data::DBI::Template' );
}

sub templates {
	return $_[0]->_all('templates');
}

sub comment {
	my $self	= shift;
	my $topic_id	= shift;
	my $story_id	= shift;
	my $id		= shift;

	my $c = Gruta::Data::DBI::Comment->new(
						topic_id	=> $topic_id,
						story_id	=> $story_id,
						id			=> $id
				);

	return $c->load($self);
}


sub pending_comments {
	my $self	= shift;

	my @ret = ();

	my $sth = $self->_prepare('DELETE FROM comments WHERE ctime < ?');
	$self->_execute($sth, time() - (60 * 60 * 24 * 7));

	my $sql = 'SELECT topic_id, story_id, id FROM comments ' .
				'WHERE approved = 0 ORDER BY ctime DESC';

	$sth = $self->_prepare($sql);
	$self->_execute($sth);

	while(my @r = $sth->fetchrow_array()) {
		push(@ret, [ @r ]);
	}

	return @ret;
}


sub story_comments {
	my $self	= shift;
	my $story	= shift;
	my $all		= shift;

	my @ret = ();

	# delete old non-approved comments for this story
	my $sth = $self->_prepare('DELETE FROM comments WHERE ctime < ? AND ' .
							'topic_id = ? AND story_id = ?');
	$self->_execute($sth, time() - (60 * 60 * 24 * 7),
				$story->get('topic_id'), $story->get('id'));

	my $sql = 'SELECT topic_id, story_id, id FROM comments ' .
				'WHERE topic_id = ? AND story_id = ?';

	if (!$all) {
		$sql .= ' AND approved = 1';
	}

	$sql .= ' ORDER BY ctime ASC';

	$sth = $self->_prepare($sql);
	$self->_execute($sth, $story->get('topic_id'), $story->get('id'));

	while(my @r = $sth->fetchrow_array()) {
		push(@ret, [ @r ]);
	}

	return @ret;
}


sub story {
	my $self	= shift;
	my $topic_id	= shift;
	my $id		= shift;

	my $s = Gruta::Data::DBI::Story->new( topic_id => $topic_id, id => $id );
	return $s->load( $self );
}


sub stories {
	my $self	= shift;
	my $topic_id	= shift;

	my @ret = ();

	my $sth = $self->_prepare("SELECT id FROM stories WHERE topic_id = ?");
	$self->_execute($sth, $topic_id);

	while(my @r = $sth->fetchrow_array()) {
		push(@ret, $r[0]);
	}

	return @ret;
}


sub stories_by_date {
	my $self	= shift;
	my $topics	= shift;
	my %args	= @_;

	$args{offset} += 0;
	$args{offset} = 0 if $args{offset} < 0;

	my $sql = 'SELECT topic_id, id, date FROM stories ';
	my @args = ();
	my @sql_w = ();

	if ($topics) {
		push(@sql_w, '(' . join(' OR ', map { 'topic_id = ?' } @{$topics}) . ')');
		@args = ( @{$topics} );
	}

	if ($args{from}) {
		push(@sql_w, 'date > ?');
		push(@args, $args{from});
	}

	if ($args{to}) {
		push(@sql_w, 'date < ?');
		push(@args, $args{to});
	}

	if (!$args{future}) {
		push(@sql_w, 'date <= ?');
		push(@args, Gruta::Data::today());
	}

	if (@sql_w) {
		$sql .= ' WHERE ' . join(' AND ', @sql_w);
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

	my @R = ();

	while(my @r = $sth->fetchrow_array()) {
		push(@R, [ @r ]);
	}

	return @R;
}


sub search_stories {
	my $self	= shift;
	my $topic_id	= shift;
	my $query	= shift;
	my $future	= shift;

	my @q = map { '%' . $_ . '%' } split(/\s+/, $query);
	my $cond = 'AND content LIKE ? ' x scalar(@q);

	unless ($future) {
		$cond .= 'AND date <= ? ';
		push(@q, Gruta::Data::today());
	}

	my $sql = 'SELECT id FROM stories WHERE topic_id = ? ' . $cond .
		'ORDER BY title';

	my $sth = $self->_prepare($sql);

	$self->_execute($sth, $topic_id, @q);

	my @r = ();

	while(my $r = $sth->fetchrow_arrayref()) {
		push(@r, $r->[0]);
	}

	return @r;
}


sub stories_by_text {
	my $self	= shift;
	my $topics	= shift;
	my $query	= shift;
	my $future	= shift;

	my @q = map { '%' . $_ . '%' } split(/\s+/, $query);
	my @cond;

	push(@cond, 'content LIKE ?' x scalar(@q));

	unless ($future) {
		push(@cond, 'date <= ?');
		push(@q, Gruta::Data::today());
	}

	if ($topics) {
		push(@cond, '(' .
			join(' OR ', map { 'topic_id = ?' } @{$topics}) .
			')');
		push(@q, @{$topics});
	}

	my $sql = 'SELECT topic_id, id FROM stories WHERE ' .
		join(' AND ', @cond) .
		'ORDER BY topic_id, title';

	print STDERR $sql, "\n";

	my $sth = $self->_prepare($sql);

	$self->_execute($sth, @q);

	my @r = ();

	while(my $r = $sth->fetchrow_arrayref()) {
		push(@r, [ $r->[0] , $r->[1] ]);
	}

	return @r;
}


sub stories_top_ten {
	my $self	= shift;
	my $num		= shift;

	my $sql = 'SELECT hits, topic_id, id FROM stories ' .
		'ORDER BY hits DESC LIMIT ?';

	my $sth = $self->_prepare($sql);
	$self->_execute($sth, $num);

	my @r = ();

	while (my @a = $sth->fetchrow_array()) {
		push(@r, [ @a ]);
	}

	return @r;
}


sub stories_by_tag {
	my $self	= shift;
	my $topics	= shift;
	my $tag		= shift;
	my $future	= shift;

	my @tags	= map { lc($_) } split(/\s*,\s*/, $tag);

	my @r = ();

	my @args = ( @tags );

	if (@tags) {
		my $sql = 'SELECT DISTINCT tags.topic_id, tags.id, stories.date' .
			' FROM tags, stories WHERE ' .
			'tags.topic_id = stories.topic_id AND tags.id = stories.id AND ';

		if (!$future) {
			$sql .= "stories.date <= '" . Gruta::Data::today() . "' AND ";
		}

		$sql .= '(' . join(' OR ', map { 'tag = ?' } @tags) . ')';

		if ($topics) {
			$sql .= ' AND (' .
				join(' OR ', map { 'tags.topic_id = ?' } @{$topics}) . ')';

			push(@args, @{$topics});
		}

		$sql .= ' GROUP BY tags.topic_id, tags.id HAVING count(tags.id) = ' . scalar(@tags);
		$sql .= ' ORDER BY stories.title';

		my $sth = $self->_prepare($sql);
		$self->_execute($sth, map { lc($_) } @args);

		while (my @a = $sth->fetchrow_array()) {
			push(@r, [ @a ]);
		}
	}

	return @r;
}


sub tags {
	my $self	= shift;

	my @r = ();

	my $sth = $self->_prepare(
		'SELECT tag, count(tag) FROM tags GROUP BY tag ORDER BY tag');
	$self->_execute($sth);

	while (my @a = $sth->fetchrow_array()) {
		push(@r, [ @a ]);
	}

	return @r;
}

sub session {
	return _one( @_, 'Gruta::Data::DBI::Session' );
}

sub purge_old_sessions {
	my $self	= shift;

	my $sth = $self->_prepare('DELETE FROM sids WHERE time < ?');
	$self->_execute($sth, time() - (60 * 60 * 24));

	return undef;
}


sub _insert {
	my $self	= shift;
	my $obj		= shift;
	my $table	= shift;
	my $class	= shift;

	my $sth;

	bless($obj, $class);
	$obj->source($self);

	if (not $sth = $self->{sth}->{insert}->{ref($obj)}) {
		my $sql = 'INSERT INTO ' . $table .
			' (' . join(', ', $obj->fields()) . ')' .
			' VALUES (' . join(', ', map { '?' } $obj->fields()) . ')';

		$sth = $self->{sth}->{insert}->{ref($obj)} = $self->_prepare($sql);
	}

	$self->_execute($sth, map { $obj->get($_) } $obj->fields());

	return $obj;
}

sub insert_topic {
	$_[0]->_insert($_[1], 'topics', 'Gruta::Data::DBI::Topic');
}

sub insert_user {
	$_[0]->_insert($_[1], 'users', 'Gruta::Data::DBI::User');
}

sub insert_template {
	$_[0]->_insert($_[1], 'templates', 'Gruta::Data::DBI::Template');
}

sub insert_comment {
	my $self	= shift;
	my $comment	= shift;

	if (!$comment->setup($self)) {
		return undef;
	}

	$self->_insert($comment, 'comments', 'Gruta::Data::DBI::Comment');
}


sub insert_story {
	my $self	= shift;
	my $story	= shift;

	if (not $story->get('id')) {
		# alloc an id for the story
		my $id = undef;

		my $sth = $self->_prepare(
			'SELECT 1 FROM stories WHERE topic_id = ? AND id = ?');

		do {
			$id = $story->new_id();
			$self->_execute($sth, $story->get('topic_id'), $id);

		} while $sth->fetchrow_arrayref();

		$story->set('id', $id);
	}

	$self->_insert($story, 'stories', 'Gruta::Data::DBI::Story');

	return $story;
}

sub insert_session {
	$_[0]->_insert($_[1], 'sids', 'Gruta::Data::DBI::Session');
}

sub create {
	my $self	= shift;

	eval {
		$self->{dbh}->do('SELECT count(*) FROM users');
	};

	if (! $@) {
		return $self->update_schema();
	}

	my $sql = '';

	while(<DATA>) {
		chomp;

		if (/^;$/) {
			$self->{dbh}->do($sql);
			$sql = '';
		}
		else {
			$sql .= $_;
		}
	}

	$self->{dbh}->do(
		'INSERT INTO metadata (version) VALUES (' . $schema_version . ')'
	);

	return $self;
}


sub update_schema {
	my $self = shift;

	my $st = $self->{dbh}->prepare('SELECT version FROM metadata');
	$st->execute();

	my ($version) = $st->fetchrow_array();

	while ($version < $schema_version) {
		if ($version == 1) {
			# from 1 to 2
			$self->{dbh}->do(
				'ALTER TABLE topics ADD COLUMN description VARCHAR'
			);
		}
		elsif ($version == 2) {
			# from 2 to 3
			$self->{dbh}->do(
				'ALTER TABLE stories ADD COLUMN description VARCHAR'
			);
		}
		elsif ($version == 3) {
			# from 3 to 4
			$self->{dbh}->do(
				'ALTER TABLE stories ADD COLUMN abstract VARCHAR'
			);
			$self->{dbh}->do(
				'ALTER TABLE stories ADD COLUMN body VARCHAR'
			);
		}
		elsif ($version == 4) {
			# from 4 to 5
			$self->{dbh}->do(
				'CREATE INDEX stories_by_title ON stories (title)'
			);
		}
		elsif ($version == 5) {
			# from 5 to 6
			$self->{dbh}->do(
				'CREATE TABLE templates ( ' .
				'	id		VARCHAR PRIMARY KEY,' .
				'	content		VARCHAR' .
				')'
			);
		}
		elsif ($version == 6) {
			#from 6 to 7
			$self->{dbh}->do(
				'ALTER TABLE stories ADD COLUMN toc INTEGER DEFAULT 0'
			);
		}
		elsif ($version == 7) {
			# from 7 to 8
			$self->{dbh}->do(
				'CREATE TABLE comments (' .
				'  id			VARCHAR NOT NULL,' .
				'  topic_id	VARCHAR NOT NULL,' .
				'  story_id	VARCHAR NOT NULL,' .
				'  ctime		INTEGER,' .
				'  approved	INTEGER DEFAULT 0,' .
				'  author		VARCHAR,' .
				'  content		VARCHAR,' .
				'  PRIMARY KEY	(id, topic_id, story_id)' .
				')'
			);
		}
		elsif ($version == 8) {
			#from 7 to 8
			$self->{dbh}->do(
				'ALTER TABLE comments ADD COLUMN date CHAR(14)'
			);
		}

		$version++;

		$self->{dbh}->do(
			'UPDATE metadata SET version = ' . $version
		);
	}

	return $self;
}


sub new {
	my $class = shift;

	my $s = bless( { @_ }, $class);

	$s->{dbh} = DBI->connect($s->{string},
		$s->{user}, $s->{passwd}, {
			RaiseError => 1,
			PrintError => 0
		 }
	);

	$s->create();

	return $s;
}

1;
__DATA__
CREATE TABLE metadata (
	version		INTEGER
)
;
CREATE TABLE topics (
	id		VARCHAR PRIMARY KEY,
	name		VARCHAR,
	editors		VARCHAR,
	max_stories	INTEGER,
	internal	INTEGER,
	description	VARCHAR
)
;
CREATE TABLE stories (
	id		VARCHAR NOT NULL,
	topic_id	VARCHAR NOT NULL,
	title		VARCHAR,
	date		CHAR(14),
	date2		CHAR(14),
	userid		VARCHAR,
	format		VARCHAR,
	hits		INTEGER DEFAULT 0,
	ctime		INTEGER,
	content		VARCHAR,
	description	VARCHAR,
	abstract	VARCHAR,
	body		VARCHAR,
	toc			INTEGER DEFAULT 0,
	PRIMARY KEY	(id, topic_id)
)
;
CREATE TABLE users (
	id		VARCHAR PRIMARY KEY,
	username	VARCHAR,
	email		VARCHAR,
	password	VARCHAR,
	can_upload	INTEGER,
	is_admin	INTEGER,
	xdate		CHAR(14)
)
;
CREATE TABLE sids (
	id		VARCHAR PRIMARY KEY,
	time		INTEGER,
	user_id		VARCHAR,
	ip		VARCHAR
)
;
CREATE TABLE tags (
	id		VARCHAR NOT NULL,
	topic_id	VARCHAR NOT NULL,
	tag		VARCHAR NOT NULL
)
;
CREATE TABLE templates (
	id		VARCHAR PRIMARY KEY,
	content		VARCHAR
)
;
CREATE TABLE comments (
	id			VARCHAR NOT NULL,
	topic_id	VARCHAR NOT NULL,
	story_id	VARCHAR NOT NULL,
	ctime		INTEGER,
	date		CHAR(14),
	approved	INTEGER DEFAULT 0,
	author		VARCHAR,
	content		VARCHAR,
	PRIMARY KEY	(id, topic_id, story_id)
)
;
CREATE INDEX stories_by_date ON stories (date)
;
CREATE INDEX stories_by_hits ON stories (hits)
;
CREATE INDEX tags_by_tag ON tags (tag)
;
CREATE INDEX stories_by_title ON stories (title)
;
