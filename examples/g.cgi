#!/usr/bin/perl

#!/usr/bin/perl -d:ptkdb
#sub BEGIN { $ENV{'DISPLAY'} = ":0.0"; }

use locale;
use POSIX qw (locale_h);
#setlocale(LC_ALL, 'es_ES.UTF-8');

use Gruta;
use Gruta::CGI;
use Gruta::Source::DBI;
#use Gruta::Source::FS;
use Gruta::Renderer::Grutatxt;
use Gruta::Renderer::HTML;
use Gruta::Renderer::Text;
use Gruta::Template::Artemus;

my $base = '/var/www/gruta';

my $g = Gruta->new(
	sources		=> [
		Gruta::Source::DBI->new( string => "dbi:SQLite:$base/var/gruta.db" ),
#		Gruta::Source::FS->new( path => "${base}/var" ),
	],
	renderers	=> [
		Gruta::Renderer::Grutatxt->new(),
		Gruta::Renderer::HTML->new(),
		Gruta::Renderer::HTML->new( valid_tags => undef ),
		Gruta::Renderer::Text->new(),
	],
	template	=> Gruta::Template::Artemus->new( path =>
		"${base}/var/templates" .
		':/usr/share/gruta/templates/artemus/ALL' .
		':/usr/share/gruta/templates/artemus/es'
	),
	cgi		=> Gruta::CGI->new(
		upload_dirs     => [ "${base}/img" ],
	),
	args		=> {
		base_url	=> 'http://example.com/',
	}
);

$g->run();
