package Gruta::CGI;

use CGI;
use Carp;

sub vars { return $_[0]->{cgi}->Vars(); }
sub upload_dirs { return @{ $_[0]->{upload_dirs} }; }

sub http_headers {
	my $self	= shift;
	my %headers	= @_;

	foreach my $k (keys(%headers)) {
		$self->{http_headers}->{$k} = $headers{$k};
	}

	return $self->{http_headers};
}

sub cookie {
	my $self	= shift;

	if (@_) {
		$self->http_headers( 'Set-Cookie', shift );
	}

	return $ENV{HTTP_COOKIE};
}

sub redirect { $_[0]->http_headers( 'Location', $_[1] ); }
sub status { $_[0]->http_headers( 'Status', $_[1] ); }

sub data {
	my $self	= shift;
	my $data	= shift;

	if (defined($data)) {
		$self->{data} = $data;
	}

	return $self->{data};
}


sub upload {
	my $self	= shift;
	my $dir		= shift;
	my $field	= shift;

	my $file = $self->{cgi}->param($field);
	my ($basename) = ($file =~ /([^\/\\]+)$/);

	if (! grep(/^$dir$/, $self->upload_dirs())) {
		croak "Unauthorized upload directory $dir";
	}

	my $filename = $dir . '/' . $basename;

	open F, '>' . $filename or croak "Can't write $filename";
	while(<$file>) {
		print F $_;
	}

	close F;
}


sub new {
	my $class	= shift;

	my $obj = bless( { @_ }, $class );

	$obj->{charset} ||= 'UTF-8';

	$obj->{http_headers} = {
		'Content-Type'		=> 'text/html; charset=' . $obj->{charset},
		'X-Gateway-Interface'	=> $ENV{'GATEWAY_INTERFACE'},
		'X-Server-Name'		=> $ENV{'SERVER_NAME'}
	};

	$obj->{upload_dirs} ||= [];

	$obj->{cgi} = CGI->new();

	return $obj;
}


sub run {
	my $self	= shift;

	my $data = $self->data();
	my $vars = $self->vars();

	$data->template->cgi_vars($vars);

	if ($ENV{REMOTE_USER} and my $u = $data->user($ENV{REMOTE_USER})) {
		$data->auth( $u );
	}
	elsif (my $cookie = $self->cookie()) {
		if (my ($sid) = ($cookie =~ /^sid\s*=\s*(\d+)$/)) {
			$data->auth_from_sid( $sid );
		}
	}

	my $st = 'INDEX';

	if ($vars->{t}) {
		$st = uc($vars->{t});
	}

	$st = 'INDEX' unless $st =~ /^[-\w0-9_]+$/;

	# not identified nor users found?
	if (!$data->auth() && ! $data->users()) {

		# create the admin user
		my $u = Gruta::Data::User->new(
			id		=> 'admin',
			is_admin	=> 1,
			can_upload	=> 1,
			username	=> 'Admin',
			email		=> 'webmaster@localhost'
		);

		# set a random password (to be promptly changed)
		$u->password(rand());

		# insert the user
		$data->insert_user($u);

		# create a new session
		my $session = Gruta::Data::Session->new(user_id => 'admin');
		$u->source->insert_session($session);

		my $sid = $session->get('id');
		$self->cookie("sid=$sid");

		$data->auth($u);

		$st = 'ADMIN';
	}

	my $body = undef;

	eval { $body = $data->template->process( $st ) };

	if ($@) {
		$data->log($@);
#		$self->redirect('?t=INDEX');

		$self->status(500);
		$body = "<h1>500 Internal Server Error</h1><p>$@</p>";
	}

	$self->http_headers('X-Powered-By' => 'Gruta ' . $self->data->version());

	if (!$data->auth()) {
		use Digest::MD5;
		use Encode qw(encode_utf8);

		my $md5 = Digest::MD5->new();
		$md5->add(encode_utf8($body));
		my $etag = $md5->hexdigest();

		my $inm = $ENV{HTTP_IF_NONE_MATCH} || '';

		if ($inm eq $etag) {
			$self->status(304);
			$body = '';
		}
		else {
			$self->http_headers('ETag' => $etag);
		}
	}

	my $h = $self->http_headers();
	foreach my $k (keys(%{ $h })) {
		print $k, ': ', $h->{$k}, "\n";
	}
	print "\n";

	print $body;
}

1;
