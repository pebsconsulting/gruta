use Gruta;
use Gruta::Data::DBI;

my $base = '/var/www/webon';

my $src = Gruta::Data::DBI->new(
	string	=>	"dbi:SQLite:${base}/blabla.db",
	user	=>	'coco',
	passwd	=>	'caca'
);

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
