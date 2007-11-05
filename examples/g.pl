use Gruta;

use Gruta::Data;

use Gruta::Source::DBI;
use Gruta::Source::FS;
use Gruta::Source::Mbox;
use Gruta::Renderer::Grutatxt;
use Gruta::Renderer::HTML;
use Gruta::Template::Artemus;
use Gruta::Template::TT;

use Gruta::CGI;

my $base = '/var/www/webon';

my $src = Gruta::Source::DBI->new(
	string	=>	"dbi:SQLite:g.db",
	user	=>	'coco',
	passwd	=>	'caca'
);

my $src2 = Gruta::Source::FS->new(
	path	=>	'var'
);

my $src3 = Gruta::Source::Mbox->new(
	file		=>	'./url.mbox',
	topic_id	=>	'links',
	topic_name	=>	'Links',
	index_file	=>	'/tmp/url.mbox.idx'
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

my $w = Gruta->new(
#	base		=>	$base,
#	upload		=>	[ "${base}/img" ],
#	templates	=>	[ "${base}/templates" ],
	sources		=>	[ $src2, $src3 ],
	renderers	=>	[ $rndr, $rndr2, $rndr3 ],
	template	=>	$tmpl,
	cgi		=>	Gruta::CGI->new()
);

$w->login('angel', 'test');
$w->logout();

$w->template->cgi_vars( { t => 'LOGIN', topic => 'alimentos', userid => 'angel', pass => 'test' } );

#my $str = $w->template->process("{-story_part|alimentos|200609200001|content}");
#my $str = $w->template->process("{-loop_topics|_topics_as_option|\n}");
#$str = $w->template->process("{-story_loop_by_date|noticias|10|0|_story_link_as_item_with_hits|\n}");
#$str = $w->template->process("{-loop_renderers||\n}");

my @t = $w->tags();
my @sbt = $w->search_stories_by_tag('primeros');

my $str = $w->template->process('LOGIN');

my @ts = $w->topics();

my $topic = $w->topic('pruebas');
my $topic2 = $w->topic('art');
my $topic3 = $w->topic('links');

$topic->set('editors', 'coco');
$topic->save( );

my $u = $w->user('basurilla');

my @ss = $w->stories_by_date( 'noticias', num => 10 );

@ss = $w->stories('links');
my $story_n = $w->story('links', $ss[0]);
my @t = $story_n->tags();

my $story = $w->story('alimentos', '200609200001');
my @tags = $story->tags();
$story = $w->story('art', '200210040002');
$story = $w->story('art', '200210040002');
$story = $w->story('rec', '200209020002');

$story = $w->story('pruebas', '200707250001');

$story = $w->story('tbl', '200202270001');

my $hits = $story->get('hits');
$story->set('hits', $hits + 1);
$story->save( );

my $story = Gruta::Data::Story->new( topic_id => 'pruebas',
	title => 'Testing', format => 'raw_html' );
$w->insert_story($story);

@ss = $w->search_stories('noticias', 'dieta');

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

my @l = $w->stories_top_ten(10);

$w->run();

1;
