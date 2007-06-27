use Webon2::Data;
use Webon2::Driver::DBI;

my $base = '/var/www/webon';

my $drv = Webon2::Driver::DBI->new(
	string	=>	"dbi:SQLite:g.db",
	user	=>	'coco',
	passwd	=>	'caca'
);

my $w = Webon2::Data->new(
#	base		=>	$base,
#	upload		=>	[ "${base}/img" ],
#	templates	=>	[ "${base}/templates" ],
	drivers		=>	[ $drv ]
);

my @ts = $w->topics();

my $topic = $w->topic('pruebas');
my $topic2 = $w->topic('art');

$topic->set('editors', 'coco');
$topic->save( $drv );

my $u = $drv->user('basurilla');

my @ss = $drv->stories_by_date( 'noticias', num => 10 );

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
