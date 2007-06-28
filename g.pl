use Webon2::Data;

use Webon2::Source::DBI;
use Webon2::Renderer::Grutatxt;
use Webon2::Renderer::HTML;
use Webon2::Template::Artemus;

my $base = '/var/www/webon';

my $src = Webon2::Source::DBI->new(
	string	=>	"dbi:SQLite:g.db",
	user	=>	'coco',
	passwd	=>	'caca'
);

my $rndr	= Webon2::Renderer::Grutatxt->new();
my $rndr2	= Webon2::Renderer::HTML->new();
my $rndr3	= Webon2::Renderer::HTML->new( valid_tags => undef );

my $tmpl = Webon2::Template::Artemus->new(
	path	=>	"${base}/templates"
);

my $w = Webon2::Data->new(
#	base		=>	$base,
#	upload		=>	[ "${base}/img" ],
#	templates	=>	[ "${base}/templates" ],
	sources		=>	[ $src ],
	renderers	=>	[ $rndr, $rndr2, $rndr3 ],
	template	=>	$tmpl
);

#my $str = $w->template("{-story_part|alimentos|200609200001|content}");
my $str = $w->template("{-loop_topics|<option value='&'></option>|\n}");

my @ts = $w->topics();

my $topic = $w->topic('pruebas');
my $topic2 = $w->topic('art');

$topic->set('editors', 'coco');
$topic->save( );

my $u = $src->user('basurilla');

my @ss = $src->stories_by_date( 'noticias', num => 10 );

my $story = $w->story('alimentos', '200609200001');
$story = $w->story('art', '200210040002');
$story = $w->story('art', '200210040002');

#my $data = Webon2::Data->new(
#	sources		=>	[
#		Webon2::Source::DBI->new(
#			string	=>	"dbi:SQLite:${base}/blabla.db",
#			user	=>	'coco',
#			passwd	=>	'caca'
#		),
#	]
#);

#my $src2 = Webon::Source::FS->new(
#	path	=>	"${base}/var"
#);

my $w = Webon2->new(
	base		=>	$base,
	upload		=>	[ "${base}/img" ],
	templates	=>	[ "${base}/templates" ],
	sources		=>	[ $src ]
);

$w->run();
