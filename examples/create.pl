#!/usr/bin/perl

use Gruta::Source::DBI;

my $src = Gruta::Source::DBI->new(
	string	=>	"dbi:SQLite:test.db",
);

$src->create();
