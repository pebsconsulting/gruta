#!/usr/bin/perl

use Gruta;
use Gruta::Source::DBI;
use Gruta::Source::FS;

my $g = Gruta->new (
	sources	=> [
		Gruta::Source::DBI->new( string => 'dbi:SQLite:g.db' )
		]
);

my $dst = Gruta::Source::FS->new( path => '/tmp/gruta_fs' );

$dst->create();
$g->transfer_to_source( $dst );
