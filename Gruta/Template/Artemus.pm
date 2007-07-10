package Gruta::Template::Artemus;

use strict;
use warnings;

use Artemus;

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

		$f{'add'} = sub { $_[0] + $_[1]; };
		$f{'sub'} = sub { $_[0] - $_[1]; };
		$f{'gt'} = sub { $_[0] > $_[1]; };
		$f{'lt'} = sub { $_[0] < $_[1]; };

		$f{topic_part} = sub {
			my $topic_id	= shift;
			my $part	= shift;

			my $t = $data->topic($topic_id);
			return $t->get($part);
		};

		$f{story_part} = sub {
			my $topic_id	= shift;
			my $id		= shift;
			my $part	= shift;

			my $s = $data->story($topic_id, $id);
			return $s->get($part);
		};

		$f{user_part} = sub {
			my $user_id	= shift;
			my $part	= shift;

			my $s = $data->user($user_id);
			return $s->get($part);
		};

		$f{loop_topics} = sub {
			my $template	= shift;
			my $sep		= shift;

			return join($sep, map { "{-$template|$_}" } $data->topics());
		};

		$f{loop_users} = sub {
			my $template	= shift;
			my $sep		= shift;

			return join($sep, map { "{-$template|$_}" } $data->users());
		};

		$f{loop_renderers} = sub {
			my $template	= shift;
			my $sep		= shift;

			return join($sep, map { "{-$template|$_}" }
				sort(keys(%{$data->{renderers_h}})));
		};

		$f{story_loop_by_date} = sub {
			my $topic	= shift;
			my $num		= shift;
			my $offset	= shift;
			my $template	= shift;
			my $sep		= shift;

			return join($sep, map { "{-$template|$topic|$_}" }
				$data->stories_by_date(
					$topic,
					num	=> $num,
					offset	=> $offset
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

		$f{login} = sub {
			my $user_id	= shift;
			my $password	= shift;
			my $error_msg	= shift;

			if (my $sid = $data->login($user_id, $password)) {
				$data->cgi->cookie("sid=$sid");
				$data->cgi->redirect('?t=INDEX');
				$self->{abort} = 1;
			}

			return $error_msg;
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


sub link_to_topic { return '{-l|TOPIC|' . $_[1] . '}'; }
sub link_to_story { return '{-l|STORY|' . $_[1] . '|' . $_[2] . '}'; }
sub process { $_[0]->_artemus->process('{-' . $_[1] . '}'); }

sub templates {
	my $self	 = shift;

	my @r = ();

	if (opendir D, $self->{path}) {
		while (my $l = readdir D) {
			next if -d $self->{path} . '/' . $l;
			push @r, $l;
		}

		closedir D;
	}

	return @r;
}


sub template {
	my $self	= shift;
	my $template_id	= shift;

	my $content = undef;

	return $content;
}


sub save_template {
	my $self	= shift;
	my $template_id	= shift;
	my $content	= shift;
}


1;
