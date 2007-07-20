#!/usr/bin/perl

use Gruta;

#sub BEGIN { $ENV{'DISPLAY'} = ":0.0"; } #!/usr/bin/perl -d:ptkdb

use Gruta::CGI;
use Gruta::Source::DBI;
use Gruta::Renderer::Grutatxt;
use Gruta::Renderer::HTML;
use Gruta::Template::Artemus;

my $base = '/var/www/gruta';

my $g = Gruta->new(
	sources		=> [
		Gruta::Source::DBI->new( string => "dbi:SQLite:$base/gruta.db" ),
	],
	renderers	=> [
		Gruta::Renderer::Grutatxt->new(),
		Gruta::Renderer::HTML->new(),
		Gruta::Renderer::HTML->new( valid_tags => undef ),
	],
	template	=> Gruta::Template::Artemus->new( path => "$base/templates" ),
	cgi		=> Gruta::CGI->new()
);

$g->run();
