#!/usr/bin/perl

use Gruta::Source::FS;
use Gruta::Source::DBI;

#my $src = Gruta::Source::FS->new(
#	path => '/home/angel/tmp/gruta-test'
#);
my $src = Gruta::Source::DBI->new(
	string => 'dbi:SQLite:/home/angel/tmp/gruta-test.db'
);

$src->create();

my $c = Gruta::Data::Comment->new();

$c->set('topic_id', 'main');
$c->set('story_id', 'index');
$c->set('content', 'This is <b>a</b> comment.');

$c = $src->insert_comment($c);

my $c2 = $src->comment('main', 'index', $c->get('id'));

print $c2->get('id'), "\n";

my @p = $src->pending_comments();

$c->approve();

$c->delete();
