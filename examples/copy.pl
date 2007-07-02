#!/usr/bin/perl

use Gruta::Data;

use Gruta::Source::DBI;

my $g = Gruta::Data->new (
	sources	=> [
		Gruta::Source::DBI->new( string => 'dbi:SQLite:g.db' )
		]
);

my $dst = Gruta::Source::DBI->new( string => 'dbi:SQLite:/tmp/copy.db' );

$dst->create();
$g->copy( $dst );
