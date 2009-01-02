package Gruta::Template::Artemus;

use strict;
use warnings;
use Carp;

use base 'Gruta::Template::BASE';

use Artemus;
use Gruta::Data;

sub new {
	my $class	= shift;
	my %args	= @_;

	my $a = bless( {}, $class );

	$a->{_artemus} = undef;
	$a->{path} = $args{path};

	$a->create();

	return $a;
}


sub _artemus {
	my $self	= shift;

	if (not $self->{_artemus}) {
		my $data = $self->data();

		my %f = ();
		my %v = ();

		$f{url} = sub {
			my $t = shift;

			return $data->url($t, @_);
		};

		$f{aurl} = sub {
			my $t = shift;

			my $ret = $data->url($t, @_);

			if ($ret !~ /^http:/) {
				$ret = "http://{-cfg_host_name}/$ret";
			}

			return $ret;
		};

		$f{date} = sub {
			my $fmt	= shift;
			my $d	= shift || Gruta::Data::today();

			return Gruta::Data::format_date($d, $fmt);
		};

		foreach my $p (Gruta::Data::Topic->new->afields()) {
			$f{'topic_' . $p} = sub {
				my $topic = shift;
				my $ret = '';

				if ($topic ne '[]') {
					if (my $topic = $data->topic($topic)) {
						$ret = $topic->get($p) || '';
					}
				}

				return $ret;
			};
		}

		foreach my $p (Gruta::Data::Story->new->afields()) {
			$f{'story_' . $p} = sub {
				my $topic_id	= shift;
				my $id		= shift;
				my $ret		= '';

				if ($id ne '[]') {
					my $story;

					if ($story = $data->story($topic_id, $id)) {
						$ret = $story->get($p);
					}
				}

				return $self->{_artemus}->armor($ret);
			};
		}

		$f{story_abstract} = sub {
			my $story = $data->story($_[0], $_[1]);
			my $ret = $data->special_uris($story->get('abstract'));

			return $self->{_artemus}->armor($ret);
		};

		$f{story_body} = sub {
			my $topic_id	= shift;
			my $id		= shift;
			my $ret		= undef;

			if (my $topic = $data->topic($topic_id)) {
				if (my $story = $data->story($topic_id, $id)) {
					my $date2 = $story->get('date2');

					# if no user and story is not freed, bounce
					if (!$data->auth() && $date2 && $date2 > Gruta::Data::today()) {
						# return directly to avoid armoring
						return '{-restricted_access}';
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

			return $self->{_artemus}->armor($ret);
		};

		$f{story_date} = sub {
			my $format	= shift;
			my $topic_id	= shift;
			my $id		= shift;
			my $ret		= '';

			if ($id ne '[]') {
				my $story;

				if ($story = $data->story($topic_id, $id)) {
					$ret = $story->date($format);
				}
			}

			return $self->{_artemus}->armor($ret);
		};

		$f{story_date2} = sub {
			my $format	= shift;
			my $topic_id	= shift;
			my $id		= shift;
			my $ret		= '';

			if ($id ne '[]') {
				my $story;

				if ($story = $data->story($topic_id, $id)) {
					$ret = $story->date2($format);
				}
			}

			return $self->{_artemus}->armor($ret);
		};

		foreach my $p (Gruta::Data::User->new->afields()) {
			$f{'user_' . $p} = sub {
				my $id	= shift;
				my $ret	= '';

				if ($id ne '[]') {
					$ret = $data->user($id)->get($p);
				}

				return $self->{_artemus}->armor($ret);
			};
		}

		$f{user_xdate} = sub {
			my $format	= shift;
			my $id		= shift;
			my $ret		= '';

			if ($id ne '[]') {
				$ret = $data->user($id)->xdate($format);
			}

			return $ret;
		};

		$f{template} = sub {
			my $t = shift;
			my $ret = '';

			if ($t ne '[]') {
				$t = $data->template->template($t);
				$ret = $self->{_artemus}->armor($t);
			}

			return $ret;
		};

		$f{save_template} = sub {
			my $template	= shift;
			my $content	= shift;
			my $msg		= shift;

			$content = $self->{_artemus}->unarmor($content);
			$data->template->save_template($template, $content);

			return $msg || "OK";
		};

		$f{is_logged_in} = sub {
			return $data->auth() ? 1 : 0;
		};

		$f{is_admin} = sub {
			return $data->auth() && $data->auth->get('is_admin') ? 1 : 0;
		};

		$f{is_topic_editor} = sub {
			if (my $topic = $data->topic($_[0])) {
				return $topic->is_editor($data->auth()) ? 1 : 0;
			}

			return 0;
		};

		$f{login} = sub {
			my $user_id	= shift;
			my $password	= shift;
			my $error_msg	= shift;

			if ($user_id eq '' || $user_id eq 'cgi-userid') {
				$error_msg = '{-block_login}';
			}
			elsif (my $sid = $data->login($user_id, $password)) {
				$data->cgi->cookie("sid=$sid");
				$data->cgi->redirect('INDEX');
				$self->{abort} = 1;
			}

			return $error_msg || 'Login incorrect.';
		};

		$f{logout} = sub {
			$data->logout();
			$data->cgi->redirect('INDEX');
			$self->{abort} = 1;
		};

		$f{assert} = sub {
			my $cond	= shift;
			my $redir	= shift || 'ADMIN';

			if (! $cond) {
				$data->cgi->redirect($redir);
				$self->{abort} = 1;
			}

			return '';
		};

		$f{username} = sub {
			return $data->auth() && $data->auth->get('username') || '';
		};

		$f{userid} = sub {
			return $data->auth() && $data->auth->get('id') || '';
		};

		$f{search_stories} = sub {
			my $topic_id	= shift;
			my $query 	= shift;
			my $future	= shift;
			my $template	= shift || 'link_to_story_with_edit';
			my $sep		= shift || '';

			my $ret = '';
			my @l = $data->search_stories($topic_id, $query, $future);

			if (@l) {
				$ret = "<p><b>{-topic_name|$topic_id}</b><br>\n";

				$ret .= '<ul>';
				$ret .= join($sep, map { "<li>{-$template|$topic_id|$_}</li>" } @l);
				$ret .= '</ul>';

				$self->{search_count} += scalar(@l);
			}

			return $ret;
		};

		$f{is_visible_story} = sub {
			if (my $story = $data->story($_[0], $_[1])) {
				return $story->is_visible($data->auth()) ? 1 : 0;
			}

			return 0;
		};

		$f{redir_if_archived} = sub {
			my $template	= shift;
			my $topic_id	= shift;
			my $id		= shift;

			if ($topic_id =~ /-arch$/) {
				return '';
			}

			my $story = $data->story($topic_id, $id);

			if ($story && $story->get('topic_id') =~ /-arch$/) {
				$data->cgi->redirect(
					$template,
					'topic'	=> $story->get('topic_id'),
					'id'	=> $id
				);
				$self->{abort} = 1;
			}

			return '';
		};

		$f{topic_has_archive} = sub {
			return $data->topic($_[0] . '-arch') ? 1 : 0;
		};

		$f{save_topic} = sub {
			my $topic_id	= shift || return 'Error 1';

			my $topic = undef;

			if (not $topic = $data->topic($topic_id)) {
				$topic = Gruta::Data::Topic->new (
					id => $topic_id );
			}

			$topic->set('name',		shift);
			$topic->set('editors',		shift);
			$topic->set('internal', 	shift eq 'on' ? 1 : 0);
			$topic->set('max_stories',	shift);
			$topic->set('description',	shift);

			# update or insert
			if ($topic->source()) {
				$topic = $topic->save();
			}
			else {
				$topic = $data->insert_topic($topic);
			}

			return $topic ? 'OK' : 'Error 2';
		};

		$f{save_story} = sub {
			my $topic_id	= shift || return 'Error 1';
			my $id		= shift;

			my $story = undef;

			if (not $story = $data->story($topic_id, $id)) {
				$story = Gruta::Data::Story->new (
					topic_id	=> $topic_id,
					id		=> $id
				);
			}

			my $content = shift;
			$content = $self->{_artemus}->unarmor($content);
			$content =~ s/\r//g;

			$story->set('content',	$content);

			# pick date and drop time
			my $y = shift;
			my $m = shift;
			my $d = shift;
			shift; shift; shift;
			my $date = Gruta::Data::today();

			if ($y && $m && $d) {
				$date = sprintf("%04d%02d%02d000000", $y, $m, $d);
			}

			$story->set('date',	$date);
			$story->set('format',	shift || 'grutatxt');

			# get the tags
			my $tags = shift;

			# get date2
			$y = shift;
			$m = shift;
			$d = shift;

			if ($y && $m && $d) {
				$date = sprintf("%04d%02d%02d000000", $y, $m, $d);
			}
			else {
				$date = '';
			}

			$story->set('date2', $date);

			$story->set('description', shift);

			# if there is no userid, add one
			if (!$story->get('userid')) {
				$story->set('userid', $data->auth->get('id'));
			}

			# drop all cached stories
			$data->flush_story_cache();

			# render the story
			$data->render($story);

			if ($story->source()) {
				$story = $story->save();
			}
			else {
				$story = $data->insert_story($story);
			}

			if ($tags ne 'cgi-tags') {
				$story->tags(split(/\s*,\s*/, $tags));
			}

			return $story ? $story->get('id') : 'Error 2';
		};

		$f{save_user} = sub {
			shift;	# new (ignored)
			my $id		= shift || return 'Error 1';
			my $username	= shift;
			my $email	= shift;
			my $is_admin	= shift;
			my $can_upload	= shift;
			my $pass1	= shift;
			my $pass2	= shift;
			my $xy		= shift;
			my $xm		= shift;
			my $xd		= shift;

			if ($data->auth->get('username') ne $username &&
				! $data->auth->get('is_admin')) {
				$data->cgi->redirect('LOGIN');
				$self->{abort} = 1;
				return '';
			}

			my $user = undef;

			if (not $user = $data->user($id)) {
				$user = Gruta::Data::User->new (
					id		=> $id,
					is_admin	=> 0,
					can_upload	=> 0,
					xdate		=> ''
				);
			}

			$user->set('username',		$username);
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
				$user = $data->insert_user($user);
			}

			return $user ? 'OK' : 'Error 2';
		};

		$f{upload} = sub {

			$data->cgi->upload($_[0], $_[1]);
			return 'OK';
		};

		$f{delete_story} = sub {
			my $topic_id	= shift || return 'Error 1';
			my $id		= shift;

			$data->story($topic_id, $id)->delete();

			# drop all cached stories
			$data->flush_story_cache();

			return 'OK';
		};

		$f{search_count} = sub { $self->{search_count}; };

		$f{content_type} = sub {
			$data->cgi->http_headers('Content-Type' => $_[0]);
			return '';
		};

		$f{topics}	= sub { join(':', $data->topics()); };
		$f{templates}	= sub { join(':', $data->template->templates()); };
		$f{users}	= sub { join(':', $data->users()); };

		$f{renderers}	= sub { join(':', sort(keys(%{$data->{renderers_h}}))); };
		$f{upload_dirs}	= sub { join(':', $data->cgi->upload_dirs()); };
		$f{tags}	= sub { join(':', map { $_->[0] . ',' . $_->[1] } $data->tags()); };

		$f{var}		= sub {
			my $ret = $self->{cgi_vars}->{$_[0]} || $_[1] || '';

			return $self->{_artemus}->armor($ret);
		};

		$f{story_tags} = sub {
			my $topic_id	= shift;
			my $id		= shift;
			my $ret		= '';

			if ($id ne '[]') {
				if (my $story = $data->story($topic_id, $id)) {
					$ret = join(':', $story->tags());
				}
			}

			return $ret;
		};

		$f{stories_by_date} = sub {
			my $topic	= shift;
			my $num		= shift;
			my $offset	= shift;
			my $from_date	= shift;
			my $to_date	= shift;
			my $future	= shift;

			my @ret = map { join(',', @{$_}) }
				$data->stories_by_date(
					$topic ?
						[ map { (split(',', $_))[0] }
							split(':', $topic)
						] : undef,
					num	=> $num,
					offset	=> $offset,
					from	=> $from_date,
					to	=> $to_date,
					future	=> $future
			);

#			$self->{search_count} += scalar(@ret);

			return join(':', @ret);
		};

		$f{stories_by_tag} = sub {
			my $topic	= shift;
			my $tag		= shift;
			my $future	= shift;

			my @ret = $data->stories_by_tag(
				$topic ?
					[ map { (split(',', $_))[0] }
						split(':', $topic)
					] : undef,
				$tag, $future);

			$self->{search_count} += scalar(@ret);

			return join(':', map { $_->[0] . ',' . $_->[1] } @ret);
		};

		$f{stories_top_ten} = sub {
			my $num		= shift;

			return join(':', map { join(',', @{$_}) }
				$data->stories_top_ten($num)
			);
		};

		$f{about} = sub {
			return 'Gruta ' . $data->version();
		};

		$self->{abort}		= 0;
		$self->{unresolved}	= [];
		$self->{search_count}	= 0;

		$self->{_artemus} = Artemus->new(
			'include-path'	=>	$self->{path},
			'funcs'		=>	\%f,
			'vars'		=>	\%v,
			'unresolved'	=>	$self->{unresolved},
			'abort'		=>	\$self->{abort},
		);

		if ($self->{cgi_vars}) {
			foreach my $k (keys(%{ $self->{cgi_vars} })) {
				my $c = $self->{_artemus}->
					armor($self->{cgi_vars}->{$k});
				$c =~ s/\r//g;

				$v{"cgi-${k}"} = $c;
			}
		}
	}

	return $self->{_artemus};
}


sub data {
	my $self	= shift;
	my $data	= shift;

	if (defined($data)) {
		$self->{data} = $data;
		$self->{_artemus} = undef;
	}

	return $self->{data};
}


sub cgi_vars {
	my $self	= shift;

	if (@_) {
		$self->{cgi_vars} = shift;
		$self->{_artemus} = undef;
	}

	return $self->{cgi_vars};
}


sub process {
	my $self	= shift;
	my $st		= shift;

	my $ret = $self->_artemus->process('{-' . $st . '}');

	# process special HTML variables
	my $t;

	if ($t = $self->{_artemus}->{vars}->{html_title}) {
		$ret =~ s!</head>!<title>$t</title></head>!i;
	}

	if ($t = $self->{_artemus}->{vars}->{html_description}) {
		$ret =~ s!</head>!<meta name="description" content="$t"></head>!i;
	}

	if ($t = $self->{_artemus}->{vars}->{html_keywords}) {
		$ret =~ s!</head>!<meta name="keywords" content="$t"></head>!i;
	}

	return $ret;
}

1;
