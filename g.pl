use Gruta::Data;

use Gruta::Source::DBI;
use Gruta::Source::FS;
use Gruta::Renderer::Grutatxt;
use Gruta::Renderer::HTML;
use Gruta::Template::Artemus;
use Gruta::Template::TT;

my $base = '/var/www/webon';

my $src = Gruta::Source::DBI->new(
	string	=>	"dbi:SQLite:g.db",
	user	=>	'coco',
	passwd	=>	'caca'
);

my $src2 = Gruta::Source::FS->new(
	path	=>	'var'
);

my $rndr	= Gruta::Renderer::Grutatxt->new();
my $rndr2	= Gruta::Renderer::HTML->new();
my $rndr3	= Gruta::Renderer::HTML->new( valid_tags => undef );

my $tmpl = Gruta::Template::Artemus->new(
	path	=>	"./templates/artemus"
);

my $tmpl2 = Gruta::Template::TT->new(
	path	=>	"./templates/tt"
);

my $w = Gruta::Data->new(
#	base		=>	$base,
#	upload		=>	[ "${base}/img" ],
#	templates	=>	[ "${base}/templates" ],
	sources		=>	[ $src ],
	renderers	=>	[ $rndr, $rndr2, $rndr3 ],
	template	=>	$tmpl
);

#my $str = $w->template("{-story_part|alimentos|200609200001|content}");
#my $str = $w->template->process("{-loop_topics|_topics_as_option|\n}");
#$str = $w->template->process("{-story_loop_by_date|noticias|10|0|_story_link_as_item_with_hits|\n}");
#$str = $w->template->process("{-loop_renderers||\n}");

my $str = $w->template->process('ADMIN');

my @ts = $w->topics();

my $topic = $w->topic('pruebas');
my $topic2 = $w->topic('art');

$topic->set('editors', 'coco');
$topic->save( );

my $u = $w->user('basurilla');

my @ss = $w->stories_by_date( 'noticias', num => 10 );

my $story = $w->story('alimentos', '200609200001');
$story = $w->story('art', '200210040002');
$story = $w->story('art', '200210040002');
$story = $w->story('rec', '200209020002');

my $hits = $story->get('hits');
$story->set('hits', $hits + 1);
$story->save( );

my $story = Gruta::Data::Story->new( topic_id => 'pruebas',
	title => 'Testing', format => 'raw_html' );
$w->insert_story($story);

#my $data = Gruta::Data->new(
#	sources		=>	[
#		Gruta::Source::DBI->new(
#			string	=>	"dbi:SQLite:${base}/blabla.db",
#			user	=>	'coco',
#			passwd	=>	'caca'
#		),
#	]
#);

#my $src2 = Webon::Source::FS->new(
#	path	=>	"${base}/var"
#);

my $w = Gruta->new(
	base		=>	$base,
	upload		=>	[ "${base}/img" ],
	templates	=>	[ "${base}/templates" ],
	sources		=>	[ $src ]
);

$w->run();
