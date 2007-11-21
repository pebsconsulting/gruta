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

	return $a;
}


sub _artemus {
	my $self	= shift;

	if (not $self->{_artemus}) {
		my $data = $self->data();

		my %f = ();
		my %v = ();

		$f{l} = sub {
			my $t = shift;

			return '?t=' . $t . ';' . join(';', @_);
		};

		$f{'add'} = sub { $_[0] + $_[1]; };
		$f{'sub'} = sub { $_[0] - $_[1]; };
		$f{'gt'} = sub { $_[0] > $_[1]; };
		$f{'lt'} = sub { $_[0] < $_[1]; };
		$f{'eq'} = sub { $_[0] eq $_[1] ? 1 : 0; };

		$f{date} = sub { Gruta::Data::today(); };
		$f{random} = sub { $_[rand(scalar(@_))]; };

		foreach my $p (Gruta::Data::Topic->new->afields()) {
			$f{'topic_' . $p} = sub {
				my $topic = shift;
				my $ret = '';

				if ($topic ne '[]') {
					$ret = $data->topic($topic)->get($p) || '';
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
					$ret = $data->story($topic_id, $id)->get($p);
				}

				return $ret;
			};
		}

		$f{story_tags} = sub {
			my $topic_id	= shift;
			my $id		= shift;
			my $ret		= '';

			if ($id ne '[]') {
				my $story = $data->story($topic_id, $id);

				$ret = join(', ', $story->tags());
			}

			return $ret;
		};

		$f{story_abstract} = sub {
			my $story = $data->story($_[0], $_[1]);

			return $data->special_uris($story->get('abstract'));
		};

		$f{story_body} = sub {
			my $story = $data->story($_[0], $_[1]);

			if (not $data->auth()) {
				$story->touch();
			}

			return $data->special_uris($story->get('body'));
		};

		$f{story_date} = sub {
			my $format	= shift;
			my $topic_id	= shift;
			my $id		= shift;
			my $ret		= '';

			if ($id ne '[]') {
				$ret = $data->story($topic_id, $id)->date($format);
			}

			return $ret;
		};

		$f{story_date2} = sub {
			my $format	= shift;
			my $topic_id	= shift;
			my $id		= shift;
			my $ret		= '';

			if ($id ne '[]') {
				$ret = $data->story($topic_id, $id)->date2($format);
			}

			return $ret;
		};

		foreach my $p (Gruta::Data::User->new->afields()) {
			$f{'user_' . $p} = sub {
				my $id	= shift;
				my $ret	= '';

				if ($id ne '[]') {
					$ret = $data->user($id)->get($p);
				}

				return $ret;
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

			return $msg || "Template saved.";
		};

		$f{loop_topics} = sub {
			my $template	= shift;
			my $sep		= shift;

			return join($sep, map {
				my $t = $data->topic($_);
				sprintf('{-%s|%s|%s}',
					$template, $t->get('name'),
					$t->get('id')
				);
			} $data->topics());
		};

		$f{loop_users} = sub {
			return join($_[1], map { "{-$_[0]|$_}" } $data->users());
		};

		$f{loop_renderers} = sub {
			return join($_[1], map { "{-$_[0]|$_}" }
				sort(keys(%{$data->{renderers_h}})));
		};

		$f{loop_templates} = sub {
			return join($_[1], map { "{-$_[0]|$_}" }
				$data->template->templates());
		};

		$f{loop_upload_dirs} = sub {
			return join($_[1], map { "{-$_[0]|$_}" }
				$data->cgi->upload_dirs());
		};

		$f{loop_story_tags} = sub {
			my $topic_id	= shift;
			my $id		= shift;

			return join($_[1], map { "{-$_[0]|$_}" }
				$data->story($topic_id, $id)->tags());
		};

		$f{story_loop_by_date} = sub {
			my $topic	= shift;
			my $num		= shift;
			my $offset	= shift;
			my $template	= shift;
			my $sep		= shift;
			my $from	= shift;
			my $to		= shift;
			my $future	= shift;

			return join($sep, map { "{-$template|$topic|$_}" }
				$data->stories_by_date(
					$topic,
					num	=> $num,
					offset	=> $offset,
					from	=> $from,
					to	=> $to,
					future	=> $future
				)
			);
		};

		$f{is_logged_in} = sub {
			return $data->auth() ? 1 : 0;
		};

		$f{is_admin} = sub {
			return $data->auth() && $data->auth->get('is_admin') ? 1 : 0;
		};

		$f{is_topic_editor} = sub {
			my $topic;

			return $topic = $data->topic($_[0]) &&
				$topic->is_editor($data->auth()) ? 1 : 0;
		};

		$f{login} = sub {
			my $user_id	= shift;
			my $password	= shift;
			my $error_msg	= shift;

			if ($user_id eq '' || $user_id eq 'cgi-userid') {
				$error_msg = '{-login_box}';
			}
			elsif (my $sid = $data->login($user_id, $password)) {
				$data->cgi->cookie("sid=$sid");
				$data->cgi->redirect('?t=INDEX');
				$self->{abort} = 1;
			}

			return $error_msg || 'Login incorrect.';
		};

		$f{logout} = sub {
			$data->logout();
			$data->cgi->redirect('?t=INDEX');
			$self->{abort} = 1;
		};

		$f{assert} = sub {
			my $cond	= shift;
			my $redir	= shift || 'ADMIN';

			if (! $cond) {
				$data->cgi->redirect('?t=' . $redir);
				$self->{abort} = 1;
			}

			return '';
		};

		$f{username} = sub {
			my $ret = '';

			if ($data->auth()) {
				$ret = $data->auth->get('username');
			}

			return $ret;
		};

		$f{search_stories} = sub {
			my $topic_id	= shift;
			my $query 	= shift;
			my $future	= shift;
			my $template	= shift || '_story_link_as_item_with_edit';
			my $sep		= shift || '';

			my $ret = '';
			my @l = $data->search_stories($topic_id, $query, $future);

			if (@l) {
				$ret = "<p><b>{-topic_name|$topic_id}</b><br>\n";

				$ret .= join($sep, map { "{-$template|$topic_id|$_}" } @l);

				$self->{search_count} += scalar(@l);
			}

			return $ret;
		};

		$f{story_loop_top_ten} = sub {
			my $num		= shift;
			my $internal	= shift; # ignored
			my $template	= shift;
			my $sep		= shift;

			return join($sep, map { "{-$template|$_->[1]|$_->[2]}" }
				$data->stories_top_ten($num)
			);
		};

		$f{is_visible_story} = sub {
			my $story = $data->story($_[0], $_[1]);

			if (!$data->auth() && $story->get('date') > Gruta::Data::today()) {
				return 0;
			}

			return 1;
		};

		$f{redir_if_archived} = sub {
			my $template	= shift;
			my $topic_id	= shift;
			my $id		= shift;

			if ($topic_id =~ /-arch$/) {
				return '';
			}

			my $story = $data->story($topic_id, $id);

			if ($story->get('topic_id') =~ /-arch$/) {
				$data->cgi->redirect(
					sprintf('?t=%s;topic=%s;id=%s',
					$template,
					$story->get('topic_id'),
					$id)
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

			# drop all cached stories
			$data->flush_story_cache();

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
				$data->cgi->redirect('?t=LOGIN');
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

				my $salt = sprintf('%02d', rand(100));
				my $pw = crypt($pass1, $salt);

				$user->set('password', $pw);
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

		$f{search_stories_by_tag} = sub {
			my $tag		= shift;
			my $template	= shift;
			my $sep		= shift;
			my $future	= shift;

			my @ret = $data->search_stories_by_tag($tag, $future);
			$self->{search_count} = scalar(@ret);

			return join($sep, map { "{-$template|$_->[0]|$_->[1]}" } @ret);
		};

		$f{search_count} = sub { $self->{search_count}; };

		$f{content_type} = sub {
			$data->cgi->http_headers('Content-Type' => $_[0]);
			return '';
		};

		$f{loop_tags} = sub {
			return join($_[1], map { "{-$_[0]|$_->[0]|$_->[1]}" }
				$data->tags());
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


sub process { $_[0]->_artemus->process('{-' . $_[1] . '}'); }

1;
