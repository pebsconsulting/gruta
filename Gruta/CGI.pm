package Gruta::CGI;

use CGI;
use Carp;

sub vars {
	return $_[0]->{cgi}->Vars();
}

sub upload_dirs {
	return @{ $_[0]->{upload_dirs} };
}

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
        my $cookie = shift;

		$self->http_headers('Set-Cookie', $cookie . '; HttpOnly');
	}

	return $ENV{HTTP_COOKIE};
}

sub status {
    $_[0]->http_headers( 'Status', $_[1] );
}

sub redirect {
    my $self    = shift;
    my $t       = shift;
    my $status  = shift || 301;

    $self->status($status);
    $self->http_headers('Location', $self->data->url($t));

    return $self;
}

sub filter_comment {
	my $self	= shift;
	my $content	= shift;

	# do some filtering
    $content =~ s/([<>"'&])/sprintf("&#%d;",ord($1))/ge;
	$content =~ s/\n{2,}/<p>/g;

	return $content;
}

sub validate_comment {
    my $self    = shift;
    my $comment = shift; # Gruta::Data::Comment

    # too short or too long? fail
    my $c = $comment->get('content');

#   length($c) > 8 or croak("Comment content too short");
    length($c) < 16384 or croak("Comment content too long");

    my @l = split('http:', $c);
    scalar(@l) < 8 or croak("Too much URLs in comment");

    # filter spam
    if ($c =~ /\[(url|link)=/) {
        croak("Invalid content");
    }

    # special spam validators

    # blogspam.net
    my $use_blogspam_net = $self->data->source->template('cfg_use_blogspam_net');

    if ($use_blogspam_net && $use_blogspam_net->get('content')) {
        eval("use RPC::XML::Client;");

        if (!$@) {
            my $blogspam = RPC::XML::Client->new(
                'http://test.blogspam.net:8888/');

            if ($blogspam) {
                my $res = $blogspam->send_request('testComment', {
                    ip      => $ENV{REMOTE_ADDR},
                    comment => $comment->get('content'),
                    agent   => $ENV{HTTP_USER_AGENT},
                    name    => $comment->get('author')
                    }
                );

                if (ref($res)) {
                    my $r = $res->value();

#                   print STDERR "blogspam.net " . $r . "\n";

                    if ($r =~ /^SPAM:/) {
                        croak("Comment rejected as " . $r . ' (blogspam.net)');
                    }
                }
            }
        }
	}

    # Akismet
    eval("use Net::Akismet;");

    if (!$@) {
        # validate with Akismet

        # pick API key and hostname templates
        my $api_key_t   = $self->data->source->template('cfg_akismet_api_key');
        my $url_t       = $self->data->source->template('cfg_akismet_url');

        if ($api_key_t && $url_t) {
            my $api_key = $api_key_t->get('content');
            my $url     = $url_t->get('content');

            if ($api_key && $url) {
                my $akismet = Net::Akismet->new(
                    KEY => $api_key,
                    URL => $url
                );

                if ($akismet) {
                    my $ret = $akismet->check(
                        USER_IP             => $ENV{REMOTE_ADDR},
                        COMMENT_USER_AGENT  => $ENV{HTTP_USER_AGENT},
                        COMMENT_CONTENT     => $comment->get('content'),
                        COMMENT_AUTHOR      => $comment->get('author'),
                        REFERRER            => $ENV{HTTP_REFERER} 
                    );

#                   print STDERR "Akismet said: ", $ret, "\n";

                    if ($ret && $ret eq 'true') {
                        croak('Comment rejected as SPAM (Akismet)');
                    }
                }
            }
        }
    }

    return $self;
}

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

	# create the directory
	mkdir $dir;

	my $filename = $dir . '/' . $basename;

	open F, '>' . $filename or croak "Can't write $filename";
	while(<$file>) {
		print F $_;
	}

	close F;
}


sub search_image {
    my $self    = shift;
    my $str     = shift;
    my $dir;
    my @ret = ();

    # find first the 'img' directory
    foreach my $d ($self->upload_dirs()) {
        if ($d =~ /\/img$/) {
            $dir = $d;
        }
    }

    if ($dir) {
        @ret = map { /\/([^\/]+)$/; $_ = $1; }
                    glob($dir . '/*' . $str . '*');
    }

    return @ret;
}


sub new {
	my $class	= shift;

	my $obj = bless( { @_ }, $class );

    $obj->{charset}                 ||= 'UTF-8';
    $obj->{min_size_for_gzip}       ||= 10000;
    $obj->{query_timeout}           ||= 20;
    $obj->{cache_control_max_age}   ||= 300;

    $obj->{http_headers} = {
        'Content-Type'          => 'text/html; charset=' . $obj->{charset},
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

    # change process name
    my $ip = $ENV{HTTP_X_FORWARDED_FOR} || $ENV{REMOTE_ADDR};
    $0 = 'Gruta:' . $data->{id} . ':' . $ip . ':' . $ENV{REQUEST_URI};

	if ($ENV{REMOTE_USER} and my $u = $data->source->user($ENV{REMOTE_USER})) {
		$data->auth( $u );
	}
	elsif (my $cookie = $self->cookie()) {
		if (my ($sid) = ($cookie =~ /sid\s*=\s*(\d+)/)) {
			$data->auth_from_sid( $sid );
		}
	}

	my $st = 'INDEX';

	if ($vars->{t}) {
		$st = uc($vars->{t});
	}

	$st = 'INDEX' unless $st =~ /^[-\w0-9_]+$/;

	# not identified nor users found?
	if (!$data->auth() && ! $data->source->users()) {

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
		$data->source->insert_user($u);

		# create a new session
		my $session = Gruta::Data::Session->new(user_id => 'admin');
		$u->source->insert_session($session);

		$self->cookie('sid=' . $session->get('id'));

		$data->auth($u);
		$data->session($session);

		$st = 'ADMIN';
	}

	my $body = undef;

	eval {
		# install a timeout handler
		$SIG{ALRM} = sub { die "Timeout processing query"; };
		alarm $self->{query_timeout};

		$body = $data->template->process( $st )
	};

	alarm 0;

	if ($@) {
		$data->log($@);
#		$self->redirect('INDEX');

		$self->status(500);
		$body = "<h1>500 Internal Server Error</h1><pre>$@</pre>";

		# main processing failed
		$self->{error} = 1;
	}

	$self->http_headers('X-Powered-By'	=> 'Gruta ' . $self->data->version());

	if (!$data->auth()) {
		use Digest::MD5;
		use Encode qw(encode_utf8);

		my $md5 = Digest::MD5->new();
		$md5->add(encode_utf8($body));
		my $etag = '"' . $md5->hexdigest() . '"';

		my $inm = $ENV{HTTP_IF_NONE_MATCH} || '';

		if ($inm eq $etag) {
			$self->status(304);
			$body = '';
		}
        else {
            $self->http_headers(
                'ETag'          => $etag,
                'Cache-Control' => 'max-age=' . $self->{cache_control_max_age}
            );
        }
	}

	# does the client accept compression?
	if (length($body) > $self->{min_size_for_gzip} &&
		$ENV{HTTP_ACCEPT_ENCODING} =~ /gzip/) {
		# compress!!
		use Compress::Zlib;

		if (my $cbody = Compress::Zlib::memGzip($body)) {
			$self->http_headers('Content-encoding' => 'gzip');
			$body = $cbody;
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
