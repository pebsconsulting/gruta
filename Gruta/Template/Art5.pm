package Gruta::Template::Art5;

use strict;
use warnings;
use Carp;

use base 'Gruta::Template::BASE';

use Art5;
use Gruta::Data;

sub new {
	my $class	= shift;
	my %args	= @_;

	my $a = bless( {}, $class );

	$a->{_art5} = undef;
	$a->{path} = $args{path};
	$a->{lang} = $args{lang} || 'en';

	if (!$a->{path}) {
		# no path? set the default one
		$a->{path} = [
			'/usr/share/gruta/templates/art5',
		];
	}

	if (!ref($a->{path})) {
		$a->{path} = [ split(':', $a->{path}) ];
	}

	return $a;
}


sub _art5 {
	my $self	= shift;

	if (not $self->{_art5}) {
		my $data = $self->data();

		my $a = Art5->new(path => $self->{path},
			'loader_func'	=>	sub {
				my $ret = undef;

				if (my $t = $data->source->template($_[0])) {
					$ret = $t->get('content');
				}

				return $ret;
			}
		);

		$a->{op}->{url} = sub {
			return $data->url(map {$a->exec($_)} @_);
		};

		$a->{op}->{aurl} = sub {
			my $ret = $data->url(map {$a->exec($_)} @_);

			if ($ret !~ /^http:/) {
				$ret = 'http://' .
					$a->exec([ 'cfg_host_name' ]) .
					$ret;
			}

			return $ret;
		};

		$a->{op}->{date} = sub {
			my $fmt	= $a->exec(shift);
			my $d	= $a->exec(shift) || Gruta::Data::today();

			return Gruta::Data::format_date($d, $fmt);
		};

		foreach my $p (Gruta::Data::Topic->new->afields()) {
			$a->{op}->{'topic_' . $p} = sub {
				my $topic	= $a->exec(shift);
				my $ret		= '';

				if ($topic ne '[]') {
					if (my $topic =	$data->source->topic($topic)) {
						$ret = $topic->get($p);
					}
				}

				return $ret;
			};
		}

		foreach my $p (Gruta::Data::Story->new->afields()) {
			$a->{op}->{'story_' . $p} = sub {
				my $topic_id	= $a->exec(shift);
				my $id			= $a->exec(shift);
				my $ret			= '';

				if ($id ne '[]') {
					my $story;

					if ($story = $data->source->story($topic_id, $id)) {
						$ret = $story->get($p);
					}
				}

				return $ret;
			};
		}

		$a->{op}->{story_abstract} = sub {
			my $topic	= $a->exec(shift);
			my $id		= $a->exec(shift);

			my $story = $data->source->story($topic, $id);
			return $data->special_uris($story->get('abstract'));
		};

		$a->{op}->{story_body} = sub {
			my $topic_id	= $a->exec(shift);
			my $id			= $a->exec(shift);
			my $ret			= undef;

			if (my $topic = $data->source->topic($topic_id)) {
				if (my $story = $data->source->story($topic_id, $id)) {
					my $date2 = $story->get('date2');

					# if no user and story is not freed, bounce
					if (!$data->auth() && $date2 && $date2 gt Gruta::Data::today()) {
						$ret = $a->exec([ 'restricted_access' ]);
					}
					else {
						# touch the story if user is not
						# (potentially) involved on it
						if (! $topic->is_editor($data->auth())) {
							$story->touch();
						}

						$ret = $data->special_uris($story->get('body'));
					}
				}
			}

			if (!defined($ret)) {
				$data->cgi->redirect('404');
				$ret = '';
			}

			return $ret;
		};

		$a->{op}->{story_date} = sub {
			my $format		= $a->exec(shift);
			my $topic_id	= $a->exec(shift);
			my $id			= $a->exec(shift);
			my $ret			= '';

			if ($id ne '[]') {
				my $story;

				if ($story = $data->source->story($topic_id, $id)) {
					$ret = $story->date($format);
				}
			}

			return $ret;
		};

		$a->{op}->{story_date2} = sub {
			my $format		= $a->exec(shift);
			my $topic_id	= $a->exec(shift);
			my $id			= $a->exec(shift);
			my $ret			= '';

			if ($id ne '[]') {
				my $story;

				if ($story = $data->source->story($topic_id, $id)) {
					$ret = $story->date2($format);
				}
			}

			return $ret;
		};

		foreach my $p (Gruta::Data::User->new->afields()) {
			$a->{op}->{'user_' . $p} = sub {
				my $id	= $a->exec(shift);
				my $ret	= '';

				if ($id ne '[]') {
					$ret = $data->source->user($id)->get($p);
				}

				return $ret;
			};
		}

		$a->{op}->{user_xdate} = sub {
			my $format	= $a->exec(shift);
			my $id		= $a->exec(shift);
			my $ret		= '';

			if ($id ne '[]') {
				$ret = $data->source->user($id)->xdate($format);
			}

			return $ret;
		};

		$a->{op}->{template} = sub {
			my $id	= $a->exec(shift);
			my $ret	= '';

			if ($id ne '[]') {
				# try to find it in the source first
				if (my $t = $data->source->template($id)) {
					$ret = $t->get('content');
				}
				else {
					# not in source; search the stock ones
					$ret = $data->template->template($id);
				}
			}

			return $ret;
		};

		$a->{op}->{save_template} = sub {
			my $id		= $a->exec(shift);
			my $content	= $a->exec(shift);

			$content =~ s/\r//g;

			my $template = $data->source->template($id);

			if (!$template) {
				$template = Gruta::Data::Template->new(id => $id);
			}

			$template->set('content', $content);

			if ($template->source()) {
				$template = $template->save();
			}
			else {
				$template = $data->source->insert_template($template);
			}

			return 'OK';
		};

		$a->{op}->{is_logged_in} = sub {
			return $data->auth() ? 1 : 0;
		};

		$a->{op}->{is_admin} = sub {
			return $data->auth() && $data->auth->get('is_admin') ? 1 : 0;
		};

		$a->{op}->{is_topic_editor} = sub {
			my $topic_id = $a->exec(shift);

			if (my $topic = $data->source->topic($topic_id)) {
				return $topic->is_editor($data->auth()) ? 1 : 0;
			}

			return 0;
		};

		$a->{op}->{login} = sub {
			my $user_id		= $a->exec(shift);
			my $password	= $a->exec(shift);
			my $error_msg	= 'Login incorrect.';

			if ($user_id eq '') {
				$error_msg = $a->exec( [ 'block_login' ]);
			}
			elsif (my $sid = $data->login($user_id, $password)) {
				$data->cgi->cookie("sid=$sid");
				$data->cgi->redirect('INDEX');
				$a->{abort} = 1;
			}

			return $error_msg;
		};

		$a->{op}->{logout} = sub {
			$data->logout();
			$data->cgi->redirect('INDEX');
			$a->{abort} = 1;
		};

		$a->{op}->{assert} = sub {
			my $cond	= $a->exec(shift);
			my $redir	= $a->exec(shift) || 'ADMIN';

			if (! $cond) {
				$data->cgi->redirect($redir);
				$a->{abort} = 1;
			}

			return '';
		};

		$a->{op}->{username} = sub {
			return $data->auth() && $data->auth->get('username') || '';
		};

		$a->{op}->{userid} = sub {
			return $data->auth() && $data->auth->get('id') || '';
		};

		$a->{op}->{search_stories} = sub {
			my $topic_id	= $a->exec(shift);
			my $query		= $a->exec(shift);
			my $future		= $a->exec(shift);

			return 'Unsupported; please use stories_by_text.';
		};

		$a->{op}->{is_visible_story} = sub {
			my $topic	= $a->exec(shift);
			my $id		= $a->exec(shift);

			if (my $story = $data->source->story($topic, $id)) {
				return $story->is_visible($data->auth()) ? 1 : 0;
			}

			return 0;
		};

		$a->{op}->{redir_if_archived} = sub {
			my $template	= $a->exec(shift);
			my $topic_id	= $a->exec(shift);
			my $id			= $a->exec(shift);

			if ($topic_id =~ /-arch$/) {
				return '';
			}

			my $story = $data->source->story($topic_id, $id);

			if ($story && $story->get('topic_id') =~ /-arch$/) {
				$data->cgi->redirect(
					$template,
					'topic'	=> $story->get('topic_id'),
					'id'	=> $id
				);
				$a->{abort} = 1;
			}

			return '';
		};

		$a->{op}->{topic_has_archive} = sub {
			my $topic = $a->exec(shift);

			return $data->source->topic($topic . '-arch') ? 1 : 0;
		};

		$a->{op}->{save_topic} = sub {
			my $topic_id = $a->exec(shift) || return 'Error 1';

			my $topic = undef;

			if (not $topic = $data->source->topic($topic_id)) {
				$topic = Gruta::Data::Topic->new(id => $topic_id );
			}

			$topic->set('name',			$a->exec(shift));
			$topic->set('editors',		$a->exec(shift));
			$topic->set('internal', 	$a->exec(shift) eq 'on' ? 1 : 0);
			$topic->set('max_stories',	$a->exec(shift));
			$topic->set('description',	$a->exec(shift));

			# update or insert
			if ($topic->source()) {
				$topic = $topic->save();
			}
			else {
				$topic = $data->source->insert_topic($topic);
			}

			return $topic ? 'OK' : 'Error 2';
		};

		$a->{op}->{save_story} = sub {
			my $topic_id	= $a->exec(shift) || return 'Error 1';
			my $id			= $a->exec(shift);
			my $story		= undef;

			# if there is an id, try to load the story
			if ($id) {
				# this may crash if id is not valid
				$story = $data->source->story($topic_id, $id);
			}

			if (!$story) {
				$story = Gruta::Data::Story->new (
					topic_id	=> $topic_id,
					id			=> $id
				);
			}

			my $content = $a->exec(shift);
			$content =~ s/\r//g;

			$story->set('content',	$content);

			# pick date and drop time
			my $y = $a->exec(shift);
			my $m = $a->exec(shift);
			my $d = $a->exec(shift);
			shift; shift; shift;
			my $date = Gruta::Data::today();

			if ($y && $m && $d) {
				$date = sprintf("%04d%02d%02d000000", $y, $m, $d);
			}

			$story->set('date',		$date);
			$story->set('format',	$a->exec(shift) || 'grutatxt');

			# get the tags
			my $tags = $a->exec(shift);

			# get date2
			$y = $a->exec(shift);
			$m = $a->exec(shift);
			$d = $a->exec(shift);

			if ($y && $m && $d) {
				$date = sprintf("%04d%02d%02d000000", $y, $m, $d);
			}
			else {
				$date = '';
			}

			$story->set('date2', $date);

			$story->set('description', $a->exec(shift));

			$story->set('toc', $a->exec(shift) eq 'on' ? 1 : 0);

			# if there is no userid, add one
			if (!$story->get('userid')) {
				$story->set('userid', $data->auth->get('id'));
			}

			# render the story
			$data->render($story);

			if ($story->source()) {
				$story = $story->save();
			}
			else {
				$story = $data->source->insert_story($story);
			}

			$story->tags(split(/\s*,\s*/, $tags));

			return $story ? $story->get('id') : 'Error 2';
		};

		$a->{op}->{save_user} = sub {
			my $id			= $a->exec(shift) || return 'Error 1';
			my $username	= $a->exec(shift);
			my $email		= $a->exec(shift);
			my $is_admin	= $a->exec(shift);
			my $can_upload	= $a->exec(shift);
			my $pass1		= $a->exec(shift);
			my $pass2		= $a->exec(shift);
			my $xy			= $a->exec(shift);
			my $xm			= $a->exec(shift);
			my $xd			= $a->exec(shift);

			if ($data->auth->get('username') ne $username &&
				! $data->auth->get('is_admin')) {
				$data->cgi->redirect('LOGIN');
				$a->{abort} = 1;
				return '';
			}

			my $user = undef;

			if (not $user = $data->source->user($id)) {
				$user = Gruta::Data::User->new (
					id			=> $id,
					is_admin	=> 0,
					can_upload	=> 0,
					xdate		=> ''
				);
			}

			$user->set('username',	$username);
			$user->set('email',		$email);

			# these params can only be set by an admin
			if ($data->auth->get('is_admin')) {

				$user->set('is_admin', $is_admin eq 'on' ? 1 : 0);
				$user->set('can_upload', $can_upload eq 'on' ? 1 : 0);

				if ($xy and $xm and $xd) {
					$user->set('xdate',
						sprintf('%04d%02d%02d000000',
							$xy, $xm, $xd));
				}
				else {
					$user->set('xdate', '');
				}
			}

			if ($pass1 and $pass2) {
				if ($pass1 ne $pass2) {
					croak "Passwords are different";
				}

				$user->password($pass1);
			}

			if ($user->source()) {
				$user = $user->save();
			}
			else {
				$user = $data->source->insert_user($user);
			}

			return $user ? 'OK' : 'Error 2';
		};

		$a->{op}->{upload} = sub {
			$data->cgi->upload($a->exec(shift), $a->exec(shift));
			return 'OK';
		};

		$a->{op}->{delete_story} = sub {
			my $topic_id	= $a->exec(shift) || return 'Error 1';
			my $id			= $a->exec(shift);

			$data->source->story($topic_id, $id)->delete();

			return 'OK';
		};

		$a->{op}->{search_count} = sub { $self->{search_count}; };

		$a->{op}->{content_type} = sub {
			$data->cgi->http_headers('Content-Type' =>
				$a->exec(shift));

			return '';
		};

		$a->{op}->{topics}		= sub { [ $data->source->topics() ]; };
		$a->{op}->{users}		= sub { [ $data->source->users() ]; };
		$a->{op}->{templates}	= sub {
			[ $data->template->templates($data->source->templates()) ];
		};

		$a->{op}->{renderers}	= sub { [ sort(keys(%{$data->{renderers_h}})) ]; };

		$a->{op}->{upload_dirs}	= sub { [ $data->cgi->upload_dirs() ]; };

		$a->{op}->{tags}		= sub {
			[ map { [ $_->[0],  $_->[1] ] } $data->source->tags() ];
		};

		$a->{op}->{story_tags} = sub {
			my $topic_id	= $a->exec(shift);
			my $id			= $a->exec(shift);
			my $ret			= [];

			if ($id ne '[]') {
				if (my $story = $data->source->story($topic_id, $id)) {
					$ret = [ $story->tags() ];
				}
			}

			return $ret;
		};

		$a->{op}->{stories_by_date} = sub {
			my $topic		= $a->exec(shift);
			my $num			= $a->exec(shift);
			my $offset		= $a->exec(shift);
			my $from_date	= $a->exec(shift);
			my $to_date		= $a->exec(shift);
			my $future		= $a->exec(shift);

			my @ret = $data->source->stories_by_date(
					$topic ?
						[ map { (split(',', $_))[0] }
							split(':', $topic)
						] : undef,
					num		=> $num,
					offset	=> $offset,
					from	=> $from_date,
					to		=> $to_date,
					future	=> $future
			);

			return [ @ret ];
		};

		$a->{op}->{stories_by_tag} = sub {
			my $topic	= $a->exec(shift);
			my $tag		= $a->exec(shift);
			my $future	= $a->exec(shift);

			my @ret = $data->source->stories_by_tag(
				$topic ?
					[ map { (split(',', $_))[0] }
						split(':', $topic)
					] : undef,
				$tag, $future);

			$self->{search_count} += scalar(@ret);

			return [ @ret ];
		};

		$a->{op}->{stories_by_text} = sub {
			my $topic	= $a->exec(shift);
			my $query	= $a->exec(shift);
			my $future	= $a->exec(shift);

			my @ret = $data->source->stories_by_text(
				$topic ?
					[ map { (split(',', $_))[0] }
						split(':', $topic)
					] : undef,
				$query, $future);

			$self->{search_count} += scalar(@ret);

			return [ @ret ];
		};

		$a->{op}->{stories_top_ten} = sub {
			my $num		= $a->exec(shift);

			return [ $data->source->stories_top_ten($num) ];
		};

		$a->{op}->{set_date} = sub {
			my $date = $a->exec(shift);

			if ($date && $data->auth() &&
				$data->auth->get('is_admin')) {
				$Gruta::Data::_today = $date;
			}

			return '';
		};

		$a->{op}->{about} = sub {
			return 'Gruta ' . $data->version();
		};

		# copy the external hash
		$a->{xh} = $self->{cgi_vars};

		# finally store
		$self->{_art5} = $a;

	}

	return $self->{_art5};
}


sub data {
	my $self	= shift;
	my $data	= shift;

	if (defined($data)) {
		$self->{data} = $data;
	}

	return $self->{data};
}


sub cgi_vars {
	my $self	= shift;

	if (@_) {
		$self->{cgi_vars} = shift;
	}

	return $self->{cgi_vars};
}


sub process {
	my $self	= shift;
	my $st		= shift;

	my $ret = $self->_art5->exec([ $st ]);

	# process special HTML variables
	my $t;

	if ($t = $self->{_art5}->{op}->{html_title}) {
		$t = $self->_art5->exec($t);
		$ret =~ s!</head>!<title>$t</title></head>!i;
	}

	if ($t = $self->{_art5}->{op}->{html_description}) {
		$t = $self->_art5->exec($t);
		$ret =~ s!</head>!<meta name="description" content="$t"></head>!i;
	}

	if ($t = $self->{_art5}->{op}->{html_keywords}) {
		$t = $self->_art5->exec($t);
		$ret =~ s!</head>!<meta name="keywords" content="$t"></head>!i;
	}

	return $ret;
}

1;