#!/usr/bin/perl

use Gruta::Source::FS;

my $src = Gruta::Source::FS->new(
	path => '/home/angel/tmp/gruta-test'
);

$src->create();

my $c = Gruta::Data::Comment->new();

$c->set('topic_id', 'main');
$c->set('story_id', 'index');
$c->set('content', 'This is <b>a</b> comment.');

$c = $src->insert_comment($c);

my $c2 = $src->comment('main', 'index', $c->get('id'));

print $c2->get('id'), "\n";

$c->approve();

$c->delete();
