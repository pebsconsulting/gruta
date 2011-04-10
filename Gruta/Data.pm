package Gruta::Data;

use strict;
use warnings;

package Gruta::Data::BASE;

use Carp;

sub fields {
	return ();
}

sub vfields {
	return ();
}

sub afields {
	return ($_[0]->fields(), $_[0]->vfields());
}

sub filter_field {
	return $_[2];
}

sub source {
	my $self	= shift;

	if (@_) {
		$self->{_source} = shift;
	}

	return $self->{_source};
}


sub _assert {
	my $self	= shift;

	my $id = $self->get('id') || '';
	$id =~ /^[\d\w_-]+$/ or confess "Bad id '$id' [" . ref($self) . '] ';

	return $self;
}

sub new {
	my $class	= shift;
	my %args	= @_;

	my $self = bless({ }, $class);

	foreach my $k ($self->afields()) {
		$self->{$k} = undef;
		$self->set($k, $args{$k});
	}

	return $self;
}

sub get {
	my $self	= shift;
	my $field	= shift;

	confess 'get ' . ref($self) . " field '$field'?" unless exists $self->{$field};

	return $self->{$field};
}

sub set {
	my $self	= shift;
	my $field	= shift;
	my $value	= shift;

	confess 'set ' . ref($self) . " field '$field'?" unless exists $self->{$field};

	$self->{$field} = $self->filter_field($field, $value);

	return $self->{$field};
}


package Gruta::Data::Topic;

use base 'Gruta::Data::BASE';

sub fields {
	return qw(id name editors max_stories internal description);
}

sub filter_field {
	my $self	= shift;
	my $field	= shift;
	my $value	= shift;

	# ensure empty numeric values are 0
	if ($field =~ /^(max_stories|internal)$/ && !$value) {
		$value = 0;
	}

	return $value;
}

sub is_editor {
	my $self	= shift;
	my $user	= shift; # Gruta::Data::User

	return $user && ($user->get('is_admin') || 
		($self->get('editors') || '')
			=~ m{\b$user->get('id')\b}) ? 1 : 0;
}

package Gruta::Data::Story;

use base 'Gruta::Data::BASE';

use Carp;

sub fields {
	return qw(id topic_id title date date2 userid format hits ctime toc has_comments full_story content description abstract body);
}

sub filter_field {
	my $self	= shift;
	my $field	= shift;
	my $value	= shift;

	# ensure empty numeric values are 0
	if ($field =~ /^(hits|ctime)$/ && !$value) {
		$value = 0;
	}

	return $value;
}

sub _assert {
	my $self	= shift;

	$self->SUPER::_assert();

	my $topic_id = $self->get('topic_id') || '';
	$topic_id =~ /^[\d\w_-]+$/ or croak "Bad topic_id";

	return $self;
}

sub date {
	return Gruta::Data::format_date($_[0]->get('date'), $_[1]);
}

sub date2 {
	return Gruta::Data::format_date($_[0]->get('date2'), $_[1]);
}

sub touch {
	return $_[0];
}

sub tags {
	my $self	= shift;
	my @ret		= undef;

	if (scalar(@_)) {
		$self->set('tags', [ @_ ]);
	}
	else {
		@ret = @{ $self->get('tags') };
	}

	return @ret;
}

sub new_id {
	my $self	= shift;

	my $id;

	do {
		$id = sprintf('%08x', int(rand(0xffffffff)));
	}
	while ($id =~ /^\d+$/);

	return $id;
}

sub is_visible {
	my $self	= shift;
	my $user	= shift; # Gruta::Data::User

	return !$user && $self->get('date') gt Gruta::Data::today() ? 0 : 1;
}


package Gruta::Data::User;

use base 'Gruta::Data::BASE';

sub fields {
	return qw(id username email password can_upload is_admin xdate);
}

sub filter_field {
	my $self	= shift;
	my $field	= shift;
	my $value	= shift;

	# ensure empty numeric values are 0
	if ($field =~ /^(can_upload|is_admin)$/ && !$value) {
		$value = 0;
	}

	return $value;
}

sub xdate {
	return Gruta::Data::format_date($_[0]->get('xdate'), $_[1]);
}

sub password {
	my $self	= shift;
	my $passwd	= shift;

	$self->set('password', Gruta::Data::crypt($passwd));

	return $self;
}


package Gruta::Data::Session;

use base 'Gruta::Data::BASE';

sub fields {
	return qw(id time user_id ip);
}

sub new {
	my $class = shift;

	my $sid = time() . $$;

	return $class->SUPER::new( id => $sid, time => time(), @_);
}


package Gruta::Data::Template;

use base 'Gruta::Data::BASE';

sub fields {
	return qw(id content);
}


package Gruta::Data::Comment;

use base 'Gruta::Data::BASE';

use Carp;

sub fields {
	return qw(id topic_id story_id ctime date approved author content);
}


sub filter_field {
	my $self	= shift;
	my $field	= shift;
	my $value	= shift;

	if ($field eq 'approved' && !$value) {
		$value = 0;
	}

	return $value;
}


sub validate {
	my $self	= shift;

	# validate the comment as acceptable;
	# if not, croak

	my $topic_id = $self->get('topic_id');
	my $story_id = $self->get('story_id');

	# invalid story? fail
	$self->source->story($topic_id, $story_id)
		or croak("Invalid story $topic_id, $story_id");

	# too short or too long? fail
	my $c = $self->get('content');

#	length($c) > 8 or croak("Comment content too short");
	length($c) < 16384 or croak("Comment content too long");

	my @l = split('http:', $c);
	scalar(@l) < 8 or croak("Too much URLs in comment");

	# filter spam
	if ($c =~ /\[(url|link)=/) {
		croak("Invalid content");
	}

	# special spam validators

	# blogspam.net
    my $use_blogspam_net = $self->source->template('cfg_use_blogspam_net');

    if ($use_blogspam_net && $use_blogspam_net->get('content')) {
    	eval("use RPC::XML::Client;");

    	if (!$@) {
    		my $blogspam = RPC::XML::Client->new(
    			'http://test.blogspam.net:8888/');

    		if ($blogspam) {
    			my $res = $blogspam->send_request('testComment', {
    				ip 		=> $ENV{REMOTE_ADDR},
    				comment	=> $self->get('content'),
    				agent	=> $ENV{HTTP_USER_AGENT},
    				name	=> $self->get('author')
    				}
    			);

    			if (ref($res)) {
    				my $r = $res->value();

#				   print STDERR "blogspam.net " . $r . "\n";

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
		my $api_key_t = $self->source->template('cfg_akismet_api_key');
		my $url_t = $self->source->template('cfg_akismet_url');

		if ($api_key_t && $url_t) {
			my $api_key = $api_key_t->get('content');
			my $url		= $url_t->get('content');

			if ($api_key && $url) {
				my $akismet = Net::Akismet->new(
					KEY => $api_key,
					URL => $url
				);

				if ($akismet) {
					my $ret = $akismet->check(
						USER_IP				=> $ENV{REMOTE_ADDR},
						COMMENT_USER_AGENT	=> $ENV{HTTP_USER_AGENT},
						COMMENT_CONTENT		=> $self->get('content'),
						COMMENT_AUTHOR		=> $self->get('author'),
						REFERRER			=> $ENV{HTTP_REFERER} 
					);

#					print STDERR "Akismet said: ", $ret, "\n";

					if ($ret && $ret eq 'true') {
						croak('Comment rejected as SPAM (Akismet)');
					}
				}
			}
		}
	}

	return $self;
}


sub setup {
	my $self	= shift;
	my $source	= shift;

	if ($source) {
		$self->source($source);
	}

	# validate the comment as acceptable
	$self->validate();

	# set the rest of data
	$self->set('id', sprintf("%08x%04x", time(), $$));
	$self->set('ctime', time());
	$self->set('date', Gruta::Data::today());

	# send comment by email
	if (!$self->get('approved')) {
		if (my $t = $self->source->template('cfg_comment_email')) {
			if (my $c = $t->get('content')) {

				open F, "|/usr/sbin/sendmail -t"
					or die "Error $!";

				my $msg =
					"From: Gruta CMS <gruta\@localhost>\n" .
					"To: $c\n" .
					"Subject: New comment waiting for approval\n" .
                    "Content-type: text/plain; charset=utf-8\n" .
					"\n" .
					$self->get('date') . ", " .
					$self->get('author') . "\n\n" .
					$self->get('content') . "\n";

				print F $msg;
				close F;
			}
		}
	}

	return $self;
}

sub date {
	return Gruta::Data::format_date($_[0]->get('date'), $_[1]);
}

package Gruta::Data;

sub format_date {
	my $date	= shift;
	my $format	= shift;

	if (!$date) {
		return '';
	}

	if ($format) {
		use POSIX;

		my ($y, $m, $d, $H, $M, $S) = ($date =~
			/^(\d{4})(\d{2})(\d{2})(\d{2})(\d{2})(\d{2})$/);

		# convert %y to %Y for compatibility
		$format =~ s/%y/%Y/g;

		$format = POSIX::strftime($format, $S, $M, $H,
					$d, $m - 1, $y - 1900);
	}
	else {
		$format = $date;
	}

	return $format;
}


$Gruta::Data::_today = undef;

sub today {
	my $format	= shift;

	my $date = $Gruta::Data::_today;

	if (!$date) {
		my ($S, $M, $H, $d, $m, $y) = (localtime)[0..5];

		$date = sprintf('%04d%02d%02d%02d%02d%02d',
			1900 + $y, $m + 1, $d, $H, $M, $S);

		$Gruta::Data::_today = $date;
	}

	return Gruta::Data::format_date($date, $format);
}


sub crypt {
	my $key		= shift;
	my $salt	= shift;

	# no salt? pick one at random
	if (!$salt) {
		$salt = sprintf('%02d', rand(100));
	}

	return crypt($key, $salt);
}

1;
