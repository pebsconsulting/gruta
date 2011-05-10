package Gruta::Source::FS;

use base 'Gruta::Source::BASE';

use strict;
use warnings;

use Gruta::Data;

package Gruta::Data::FS::BASE;

use Carp;

sub ext {
	return '.M';
}

sub _filename {
	my $self	= shift;

	$self->_assert();
	$self->source->_assert();

	return $self->source->{path} . $self->base() .
		$self->get('id') . $self->ext();
}


sub load {
	my $self	= shift;
	my $driver	= shift;

	$self->source( $driver );

	# rename old .META files into .M
	my $filename = $self->_filename();
	rename($filename . 'ETA', $filename);

	if (not open F, $filename) {
		return undef;
	}

	while (<F>) {
		chop;

		if(/^([^:]*): (.*)$/) {
			my ($key, $value) = ($1, $2);

			$key =~ s/-/_/g;

			if (grep (/^$key$/, $self->fields())) {
				$self->set($key, $value);
			}
		}
	}

	close F;

	return $self;
}

sub save {
	my $self	= shift;
	my $driver	= shift;

	$self->source( $driver ) if $driver;

	my $filename = $self->_filename();

	open F, '>' . $filename or croak "Can't write " . $filename . ': ' . $!;

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

	$self->source( $driver ) if $driver;

	unlink $self->_filename();

	return $self;
}

package Gruta::Data::FS::Story;

use base 'Gruta::Data::Story';
use base 'Gruta::Data::FS::BASE';

use Carp;

sub base {
	return Gruta::Data::FS::Topic::base() . $_[0]->get('topic_id') . '/';
}

sub fields {
	grep !/(content|topic_id|abstract|body)/, $_[0]->SUPER::fields();
}

sub vfields {
	return ($_[0]->SUPER::vfields(), 'content', 'topic_id', 'abstract', 'body');
}

sub _destroy_index {
	my $self	= shift;

	my $filename = $self->_filename();

	# destroy the topic index, to be rewritten
	# in the future by _topic_index()
	$filename =~ s!/[^/]+$!/.INDEX!;
	unlink $filename;
}

sub save {
	my $self	= shift;
	my $driver	= shift;

	$self->SUPER::save( $driver );

	my $filename = $self->_filename();
	$filename =~ s/\.M$//;

	my @d = ('', 'content', '.A', 'abstract', '.B', 'body');

	while (@d) {
		my $ext		= shift(@d);
		my $field	= shift(@d);

		open F, '>' . $filename . $ext or
			croak "Cannot write " . $filename . $ext . ': ' . $!;
		print F $self->get($field) || '';
		close F;
	}

	$self->_destroy_index();

	return $self;
}

sub touch {
	my $self = shift;

	if (! $self->source->dummy_touch()) {
		my $hits = $self->get('hits') + 1;

		$self->set('hits', $hits);

		# call $self->SUPER::save() instead of $self->save()
		# to avoid saving content (unnecessary) and deleting
		# the topic INDEX (even probably dangerous)
		$self->SUPER::save();

		$self->source->_update_top_ten($hits, $self->get('topic_id'),
			$self->get('id'));
	}

	return $self;
}

sub tags {
	my $self	= shift;
	my @ret		= ();

	my $filename = $self->_filename();
	$filename =~ s/\.M$/.T/;

	if (scalar(@_)) {
		if (open F, '>' . $filename) {
			print F join(', ', map { s/^\s+//; s/\s+$//; lc($_) } @_), "\n";
			close F;
		}
	}
	else {
		if (open F, $filename) {
			my $l = <F>;
			close F;

			chomp($l);
			@ret = split(/\s*,\s*/, $l);
		}
	}

	return @ret;
}

sub delete {
	my $self	= shift;
	my $driver	= shift;

	my $file = $self->_filename();

	$self->SUPER::delete($driver);

	# also delete content and tags
	$file =~ s/\.M$//;

	unlink $file;
	unlink $file . '.A';
	unlink $file . '.B';
	unlink $file . '.T';

	$self->_destroy_index();

	return $self;
}


sub load {
	my $self	= shift;
	my $driver	= shift;

	if (!$self->SUPER::load( $driver )) {
		return undef;
	}

	my $filename = $self->_filename();
	$filename =~ s/\.M$//;

	rename($filename . '.TAGS', $filename . '.T');

	return $self;
}


package Gruta::Data::FS::Topic;

use base 'Gruta::Data::Topic';
use base 'Gruta::Data::FS::BASE';

sub base {
	return '/topics/';
}

sub save {
	my $self	= shift;
	my $driver	= shift;

	$self->SUPER::save( $driver );

	my $filename = $self->_filename();
	$filename =~ s/\.M$//;

	mkdir $filename;

	return $self;
}

package Gruta::Data::FS::User;

use base 'Gruta::Data::User';
use base 'Gruta::Data::FS::BASE';

sub ext {
	return '';
}

sub base {
	return '/users/';
}

package Gruta::Data::FS::Session;

use base 'Gruta::Data::Session';
use base 'Gruta::Data::FS::BASE';

sub ext {
	return '';
}

sub base {
	return '/sids/';
}

package Gruta::Data::FS::Template;

use base 'Gruta::Data::Template';
use base 'Gruta::Data::FS::BASE';

sub base {
	return '/templates/';
}

sub ext {
	return '';
}

sub load {
	my $self	= shift;
	my $driver	= shift;

	$self->source($driver);

	if (not open(F, $self->_filename())) {
		return undef;
	}

	$self->set('content', join('', <F>));
	close F;

	return $self;
}


sub save {
	my $self	= shift;
	my $driver	= shift;

	$self->source($driver) if $driver;

	if (not open(F, '>' . $self->_filename())) {
		return undef;
	}

	print F $self->get('content');
	close F;

	return $self;
}


package Gruta::Data::FS::Comment;

use base 'Gruta::Data::Comment';
use base 'Gruta::Data::FS::BASE';

use Carp;

sub base {
	if (!ref($_[0])) {
		return '/comments/';
	}

	return '/comments/'	. $_[0]->get('topic_id') . '/'
					. $_[0]->get('story_id') . '/';
}

sub fields {
	grep !/content/, $_[0]->SUPER::fields();
}

sub vfields {
	return ($_[0]->SUPER::vfields(), 'content');
}


sub pending_file {
	my $self	= shift;

	my @p = split('/', $self->_filename());
	pop(@p);
	pop(@p);
	pop(@p);

	my $pending = join('/', @p) . '/.pending/' .
				join(':',
					$self->get('topic_id'),
					$self->get('story_id'),
					$self->get('id')
				);

	return $pending;
}


sub save {
	my $self	= shift;
	my $driver	= shift;

	$self->source($driver) if $driver;

	# create the directory tree
	my @p = split('/', $self->_filename());
	pop(@p);
	my $s = pop(@p);

	my $d = join('/', @p);
	if (! -d $d) {
		mkdir $d or croak "Error posting comment: $d, $!";
	}

	push(@p, $s);

	$d = join('/', @p);
	if (! -d $d) {
		mkdir $d or croak "Error posting comment: $d, $!";
	}

	$self->SUPER::save($driver);

	# write content
	my $filename = $self->_filename();
	$filename =~ s/\.M$//;

	open F, '>' . $filename or
		croak "Cannot write " . $filename . ': ' . $!;

	print F $self->get('content') || '';
	close F;

	# if not approved, write pending
	if (!$self->get('approved')) {
		open F, '>' . $self->pending_file();
		close F;
	}

	return $self;
}


sub load {
	my $self	= shift;
	my $driver	= shift;

	if (!$self->SUPER::load($driver)) {
		return undef;
	}

	my $filename = $self->_filename();
	$filename =~ s/\.M$//;

	if (open F, $filename) {
		$self->set('content', join('', <F>));
		close F;
	}

	return $self;
}


sub delete {
	my $self	= shift;
	my $driver	= shift;

	# delete content
	my $file = $self->_filename();
	unlink $file;
	$file =~ s/\.M$//;
	unlink $file;

	# delete (possible) pending
	unlink $self->pending_file();
}


sub approve {
	my $self	= shift;

	$self->set('approved', 1);
	$self->save();

	# delete (possible) pending
	unlink $self->pending_file();

	return $self;
}


package Gruta::Source::FS;

use Carp;

sub _assert {
	my $self	= shift;

	$self->{path} or croak "Invalid path";

	return $self;
}

sub _one {
	my $self	= shift;
	my $id		= shift;
	my $class	= shift;

	my $o = ${class}->new( id => $id );
	$o->load( $self );
}

sub topic {
	return _one( @_, 'Gruta::Data::FS::Topic' );
}

sub topics {
	my $self	= shift;

	my @ret = ();

	my $path = $self->{path} . Gruta::Data::FS::Topic::base();

	if (opendir D, $path) {
		while (my $id = readdir D) {
			next unless -d $path . $id;
			next if $id =~ /^\./;

			push @ret, $id;
		}

		closedir D;
	}

	return @ret;
}

sub user {
	return _one( @_, 'Gruta::Data::FS::User' );
}

sub users {
	my $self	= shift;

	my @ret = ();

	my $path = $self->{path} . Gruta::Data::FS::User::base();

	if (opendir D, $path) {
		while (my $id = readdir D) {
			next if -d $path . $id;
			push @ret, $id;
		}

		closedir D;
	}

	return @ret;
}

sub template {
	return _one(@_, 'Gruta::Data::FS::Template');
}

sub templates {
	my $self	= shift;

	my @ret = ();

	my $path = $self->{path} . Gruta::Data::FS::Template::base();

	if (opendir D, $path) {
		while (my $id = readdir D) {
			next if -d $path . $id;
			push @ret, $id;
		}

		closedir D;
	}

	return @ret;
}


sub comment {
	my $self	= shift;
	my $topic_id	= shift;
	my $story_id	= shift;
	my $id		= shift;

	my $comment = Gruta::Data::FS::Comment->new(
		topic_id	=> $topic_id,
		story_id	=> $story_id,
		id			=> $id
	);

	if (not $comment->load($self)) {
		return undef;
	}

	return $comment;
}


sub pending_comments {
	my $self = shift;

	my @ret = ();

	my $path = $self->{path} . Gruta::Data::FS::Comment::base()
							. '/.pending/';

	if (opendir D, $path) {
		while (my $id = readdir D) {
			my $f = $path . $id;

			next if -d $f;

			push @ret, [ split(':', $id) ];
		}

		closedir D;
	}

	return sort { $b->[2] cmp $a->[2] } @ret;
}


sub comments {
	my $self = shift;
	my $max = shift;

	$max ||= 20;

	my @ret = ();

	my $path = $self->{path} . Gruta::Data::FS::Comment::base();

	if (opendir BASE, $path) {
		while (my $topic_id = readdir BASE) {
			next if $topic_id =~ /^\./;

			my $f = $path . $topic_id;

			if (opendir TOPIC, $f) {
				while (my $story_id = readdir TOPIC) {
					next if $story_id =~ /^\./;

					my $sf = $f . '/' . $story_id;

					if (opendir STORY, $sf) {
						while (my $id = readdir STORY) {
							if ($id =~ /^(.+)\.M/) {
								$id = $1;
								my $c = $self->comment($topic_id,
												$story_id, $id);

								if ($c && $c->get('approved')) {
									push @ret, [ $topic_id, $story_id, $1 ];
								}
							}
						}

						closedir STORY;
					}
				}

				closedir TOPIC;
			}
		}

		closedir BASE;
	}

	@ret = sort { $b->[2] cmp $a->[2] } @ret;
	@ret = @ret[0 .. ($max - 1)];

	return grep { defined $_ } @ret;
}


sub story_comments {
	my $self	= shift;
	my $story	= shift;
	my $all		= shift;

	my @ret = ();

    my $expire_days = $self->template('cfg_comment_expire_days') || 7;

	my $topic_id = $story->get('topic_id');
	my $story_id = $story->get('id');

	my $base_path = $self->{path} . Gruta::Data::FS::Comment::base();

	my $pend_path = $base_path . '/.pending/';
	my $path = join('/', ($base_path, $topic_id, $story_id)) . '/';

	if (opendir D, $path) {
		while (my $id = readdir D) {
			my $f = $path . $id;

			next if -d $f;
			next if $f =~ /\.M$/;

			my $pf = $pend_path . join(':', ($topic_id, $story_id, $id));

			# too old? delete
			if (-f $pf && -M $f >= $expire_days) {
				unlink $f;
				unlink $f . '.M';
				unlink $pf;
				next;
			}

			# not all wanted and this comment not approved? skip
			if (!$all && -f $pf) {
				next;
			}

			push @ret, [ $topic_id, $story_id, $id ];
		}

		closedir D;
	}

	return sort { $a->[2] cmp $b->[2] } @ret;
}


sub story {
	my $self	= shift;
	my $topic_id	= shift;
	my $id		= shift;

	my $story;

	if ($story = $self->cache_story($topic_id, $id)) {
		return $story;
	}

	$story = Gruta::Data::FS::Story->new( topic_id => $topic_id, id => $id );

	if (not $story->load( $self )) {

		$story = Gruta::Data::FS::Story->new( topic_id => $topic_id . '-arch',
			id => $id );

		if (not $story->load( $self )) {
			return undef;
		}
	}

	# now load the content
	my $file = $story->_filename();
	$file =~ s/\.M$//;

	my @d = ('', 'content', '.A', 'abstract', '.B', 'body');

	while (@d) {
		my $ext		= shift(@d);
		my $field	= shift(@d);

		if (open F, $file . $ext) {
			$story->set($field, join('', <F>));
			close F;
		}
	}

	$self->cache_story($topic_id, $id, $story);

	return $story;
}

sub stories {
	my $self	= shift;
	my $topic_id	= shift;

	my @ret = ();

	if (!$self->topic($topic_id)) {
		return @ret;
	}

	my $path = $self->{path} . Gruta::Data::FS::Topic::base() . $topic_id;

	if (opendir D, $path) {
		while (my $id = readdir D) {
			if ($id =~ s/\.M$// || $id =~ s/\.META$//) {
				push(@ret, $id);
			}
		}

		closedir D;
	}
	
	return @ret;
}


sub _topic_index {
	my $self	= shift;
	my $topic_id	= shift;

	my $index = $self->{path} . Gruta::Data::FS::Topic::base() . $topic_id;

	if (! -d $index) {
		return undef;
	}

	$index .= '/.INDEX';

	if (not open I, $index) {

		my @i = ();
		foreach my $id ($self->stories($topic_id)) {
			my $story = $self->story($topic_id, $id);

			push(@i, ($story->get('date') || ('0' x 14)). ':' . $id);
		}

		open I, '>' . $index or croak "Can't create INDEX for $topic_id: $!";
		flock I, 2;

		foreach my $l (reverse(sort(@i))) {
			print I $l, "\n";
		}
	}

	close I;

	return $index;
}


sub _update_top_ten {
	my $self	= shift;
	my $hits	= shift;
	my $topic_id	= shift;
	my $id		= shift;

	my $index = $self->{path} . Gruta::Data::FS::Topic::base() . '/.top_ten';

	my $u = 0;
	my @l = ();

	if (open F, $index) {
		flock F, 1;
		while (my $l = <F>) {
			chomp($l);

			my ($h, $t, $i) = split(':', $l);

			if ($u == 0 && $h < $hits) {
				$u = 1;
				push(@l, "$hits:$topic_id:$id");
			}

			if ($i ne $id or $t ne $topic_id) {
				push(@l, $l);
			}
		}

		close F;
	}

	if ($u == 0 && scalar(@l) < $self->{hard_top_ten_limit}) {
		$u = 1;
		push(@l, "$hits:$topic_id:$id");
	}

	if ($u) {
		if (open F, '>' . $index) {
			flock F, 2;
			my $n = 0;

			foreach my $l (@l) {
				print F $l, "\n";

				if (++$n == $self->{hard_top_ten_limit}) {
					last;
				}
			}

			close F;
		}
	}

	return undef;
}


sub _stories_by_date {
	my $self	= shift;
	my $topic_id	= shift;
	my %args	= @_;

	my @r = ();

	my $i = $self->_topic_index($topic_id) or return @r;
	open I, $i or return @r;
	flock I, 1;

	my $o = 0;

	while (<I>) {
		chomp;

		my ($date, $id) = split(/:/);

		# skip future stories
		next if not $args{future} and $date gt Gruta::Data::today();

		# skip if date is above the threshold
		next if $args{'to'} and $date gt $args{'to'};

		# exit if date is below the threshold
		last if $args{'from'} and $date lt $args{'from'};

		# skip offset stories
		next if $args{'offset'} and ++$o <= $args{'offset'};

		push(@r, [ $topic_id, $id, $date ]);

		# exit if we have all we need
		last if $args{'num'} and $args{'num'} == scalar(@r);
	}

	close I;

	return @r;
}


sub stories_by_date {
	my $self	= shift;
	my $topics	= shift;
	my %args	= @_;

	my @topics;

	if (!$topics) {
		@topics = $self->topics();
	}
	else {
		@topics = @{ $topics };
	}

	if (!$args{offset} || $args{offset} < 0) {
		$args{offset} = 0;
	}

	# only one topic? execute it and return
	if (scalar(@topics) == 1) {
		return $self->_stories_by_date($topics[0], %args);
	}

	# more than one topic; 'num' and 'offset' need to be
	# calculated from the full set
	my @R = ();

	foreach my $topic_id (@topics) {

		my @r = $self->_stories_by_date($topic_id,
			%args, num => 0, offset => 0);

		push(@R, @r);
	}

	# sort by date
	@R = sort { $b->[2] cmp $a->[2] } @R;

	# split now
	if ($args{num}) {
		@R = @R[$args{offset} .. ($args{offset} + $args{num} - 1)];
	}
	else {
		@R = @R[$args{offset} .. (scalar(@R) - 1)];
	}

	return grep { defined $_ } @R;
}

sub search_stories {
	my $self	= shift;
	my $topic_id	= shift;
	my $query	= shift;
	my $future	= shift;

	my @q = split(/\s+/,$query);

	my %r = ();

	foreach my $id ($self->stories($topic_id)) {

		my $story = $self->story($topic_id, $id);

		if (!$future and $story->get('date') gt Gruta::Data::today()) {
			next;
		}

		my $content = $story->get('content');
		my $found = 0;

		# try complete query first
		if($content =~ /\b$query\b/i) {
			$found = scalar(@q);
		}
		else {
			# try separate words
			foreach my $q (@q) {
				if(length($q) > 1 and $content =~ /\b$q\b/i) {
					$found++;
				}
			}
		}

		if ($found == scalar(@q)) {
			$r{$id} = $story->get('title');
		}
	}

	return sort { $r{$a} cmp $r{$b} } keys %r;
}

sub stories_by_text {
	my $self	= shift;
	my $topics	= shift;
	my $query	= shift;
	my $future	= shift;

	my @ret;
	my @topics;

	if (!$topics) {
		@topics = $self->topics();
	}
	else {
		@topics = @{ $topics };
	}

	foreach my $t (@topics) {
		foreach my $id ($self->search_stories($t, $query, $future)) {
			push(@ret, [ $t, $id ]);
		}
	}

	return @ret;
}

sub stories_top_ten {
	my $self	= shift;
	my $num		= shift;

	my @r = ();

	my $index = $self->{path} . Gruta::Data::FS::Topic::base() . '/.top_ten';

	if (open F, $index) {
		flock F, 1;

		while (defined(my $l = <F>) and $num--) {
			chomp($l);
			push(@r, [ split(':', $l) ]);
		}

		close F;
	}

	return @r;
}


sub _collect_tags {
	my $self	= shift;
	my @topics	= @_;

	my @ret = ();

	foreach my $topic_id (@topics) {

		my $topic = $self->topic($topic_id)
			or croak("Bad topic $topic_id");

		my $files = $topic->_filename();
		$files =~ s/\.M$/\/*.T/;

		my @ls = glob($files);

		foreach my $f (@ls) {
			if (open F, $f) {
				my $tags = <F>;
				chomp $tags;
				close F;

				my ($id) = ($f =~ m{/([^/]+)\.T});

				push(@ret,
					[ $topic_id, $id, [ split(/\s*,\s*/, $tags) ] ]
				);
			}
		}
	}

	return @ret;
}


sub stories_by_tag {
	my $self	= shift;
	my $topics	= shift;
	my $tag		= shift;
	my $future	= shift;

	my @tags	= map { lc($_) } split(/\s*,\s*/, $tag);

	my @topics;

	if (!$topics) {
		@topics = $self->topics();
	}
	else {
		@topics = @{ $topics };
	}

	my %r = ();

	foreach my $tr ($self->_collect_tags(@topics)) {

		my @ts = @{$tr->[2]};

		# skip stories with less tags than the wanted ones
		if (scalar(@ts) < scalar(@tags)) {
			next;
		}

		# count matches
		my $c = 0;

		foreach my $t (@ts) {
			if (grep(/^$t$/, @tags)) {
				$c++;
			}
		}

		if ($c >= scalar(@tags)) {

			my $story = $self->story($tr->[0], $tr->[1]);

			# if no future stories are wanted, discard them
			if (!$future) {
				if ($story->get('date') gt Gruta::Data::today()) {
					next;
				}
			}

			$r{$story->get('title')} =
				[ $tr->[0], $tr->[1], $story->get('date') ];
		}
	}

	return map { $r{$_} } sort keys %r;
}


sub tags {
	my $self	= shift;

	my @ret = ();
	my %h = ();

	foreach my $tr ($self->_collect_tags($self->topics())) {

		foreach my $t (@{$tr->[2]}) {
			$h{$t}++;
		}
	}

	foreach my $k (keys(%h)) {
		push(@ret, [ $k, $h{$k} ]);
	}

	return sort { $a->[0] cmp $b->[0] } @ret;
}


sub session {
	return _one( @_, 'Gruta::Data::FS::Session' );
}

sub purge_old_sessions {
	my $self	 = shift;

	my $path = $self->{path} . Gruta::Data::FS::Session::base();

	if (opendir D, $path) {
		while(my $s = readdir D) {
			my $f = $path . $s;

			next if -d $f;

			if (-M $f > 1) {
				unlink $f;
			}
		}

		closedir D;
	}

	return undef;
}


sub _insert {
	my $self	= shift;
	my $obj		= shift;
	my $class	= shift;

	bless($obj, $class);
	$obj->save( $self );

	return $obj;
}

sub insert_topic {
	$_[0]->_insert($_[1], 'Gruta::Data::FS::Topic');
}

sub insert_user {
	$_[0]->_insert($_[1], 'Gruta::Data::FS::User');
}

sub insert_template {
	$_[0]->_insert($_[1], 'Gruta::Data::FS::Template');
}

sub insert_comment {
	$_[0]->_insert($_[1], 'Gruta::Data::FS::Comment');
}

sub insert_story {
	my $self	= shift;
	my $story	= shift;

	if (not $story->get('id')) {
		# alloc an id for the story
		my $id = undef;

		do {
			$id = $story->new_id();

		} while $self->story($story->get('topic_id'), $id);

		$story->set('id', $id);
	}

	$self->_insert($story, 'Gruta::Data::FS::Story');
	return $story;
}

sub insert_session {
	$_[0]->_insert($_[1], 'Gruta::Data::FS::Session');
}


sub create {
	my $self	= shift;

	my @l = map { $self->{path} . $_ } (
		Gruta::Data::FS::Topic::base(),
		Gruta::Data::FS::User::base(),
		Gruta::Data::FS::Session::base(),
		Gruta::Data::FS::Template::base(),
		Gruta::Data::FS::Comment::base(),
		Gruta::Data::FS::Comment::base() . '/.pending/'
	);

	foreach my $d (@l) {
		if (! -d $d) {
			mkdir $d, 0755 or die "Cannot mkdir $d";
		}
	}

	return $self;
}


sub new {
	my $class = shift;

	my $s = bless( { @_ }, $class);

	$s->{hard_top_ten_limit} ||= 100;

	$s->_assert();

	$s->create();

	return $s;
}

1;
