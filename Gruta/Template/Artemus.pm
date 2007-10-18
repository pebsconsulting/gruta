package Gruta::Template::Artemus;

use strict;
use warnings;

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

		$f{date} = sub { $data->today(); };

		foreach my $p (Gruta::Data::Topic->new->afields()) {
			$f{'topic_' . $p} = sub {
				return $data->topic($_[0])->get($p);
			};
		}

		foreach my $p (Gruta::Data::Story->new->afields()) {
			$f{'story_' . $p} = sub {
				return $data->story($_[0], $_[1])->get($p);
			};
		}

		$f{story_body} = sub {
			my $story = $data->story($_[0], $_[1]);
			my $ret = $story->get('body');

			if (not $data->auth()) {
				$story->touch();
			}

			return $ret;
		};

		$f{story_date} = sub {
			return $data->story($_[1], $_[2])->date($_[0]);
		};

		foreach my $p (Gruta::Data::User->new->afields()) {
			$f{'user_' . $p} = sub {
				return $data->user($_[0])->get($p);
			};
		}

		$f{template} = sub {
			return $data->template->template($_[0]);
		};

		$f{save_template} = sub {
			return $data->template->save_template($_[0], $_[1]);
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
			if ($data->auth() and $data->auth->get('is_admin')) {
				return 1;
			}
			return 0;
		};

		$f{is_topic_editor} = sub {
			my $auth;

			if (not $auth = $data->auth()) {
				return 0;
			}

			if ($auth->get('is_admin')) {
				return 1;
			}

			my $topic;

			if (not $topic = $data->topic($_[0])) {
				return 0;
			}

			if (my $editors = $topic->get('editors') and
				my $user_id = $auth->get('id')) {
				return 1 if $editors =~/\b$user_id\b/;
			}

			return 0;
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

		$f{assert_logged_in} = sub {
			if (not $data->auth()) {
				$data->cgi->redirect('?t=LOGIN');
				$self->{abort} = 1;
			}

			return '';
		};

		$f{assert_admin} = sub {
			if ($data->auth() and $data->auth->get('is_admin')) {
				return '';
			}

			$data->cgi->redirect('?t=LOGIN');
			$self->{abort} = 1;
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

			return "search_stories: FIXME";
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

		$f{assert_visible_story} = sub {
			my $story = $data->story($_[0], $_[1]);
			my $ret = '';

			if ($story->get('date') > $data->today()) {
				$data->cgi->redirect('?t=404');
				$self->{abort} = 1;
			}

			return $ret;
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

		$self->{abort}		= 0;
		$self->{unresolved}	= [];

		$self->{_artemus} = Artemus->new(
			'include-path'	=>	$self->{path},
			'funcs'		=>	\%f,
			'vars'		=>	\%v,
			'unresolved'	=>	$self->{unresolved},
			'abort'		=>	\$self->{abort},
		);

		if ($self->{cgi_vars}) {
			foreach my $k (keys(%{ $self->{cgi_vars} })) {
				$v{"cgi-${k}"} =
					$self->{_artemus}->armor($self->{cgi_vars}->{$k});
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
