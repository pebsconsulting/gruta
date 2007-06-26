use Webon2;
use Webon2::Sources::DBI;

my $base = '/var/www/webon';

my $src = Webon2::Sources::DBI->new(
	string	=>	"dbi:SQLite:${base}/blabla.db",
	user	=>	'coco',
	passwd	=>	'caca'
);

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
