package Gruta::Template::TT;

use strict;
use warnings;

use base 'Gruta::Template::BASE';

use Template;

sub new {
	my $class	= shift;
	my %args	= @_;

	my $t = bless( { }, $class );

	$t->{tt} = Template->new(
		'INCLUDE_PATH'	=>	$args{path},
		'INTERPOLATE'	=>	1,
		'TRIM'		=>	1
	) or die "TT: " . $Template::ERROR;

	$t->{path} = $args{path};

	return $t;
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


sub _tt_data {
	my $self	= shift;

	if (not $self->{tt_data}) {
		my $data = $self->data();
		my %f = ();

		$f{topic} = sub { return $data->topic($_[0]); };
		$f{user} = sub { return $data->user($_[0]); };
		$f{story} = sub { return $data->story($_[0], $_[1]); };

		$f{date} = sub { return $_[1]->date($_[0]); };
		$f{get} = sub { return $_[0]->get($_[1]); };

		$f{topics} = sub { return map { $data->topic($_) } $data->topics(); };
		$f{users} = sub { return map { $data->user($_) } $data->users(); };
		$f{stories} = sub { return map { $data->stories($_) } $data->stories(); };
		$f{renderers} = sub { return sort(keys(%{$data->{renderers_h}})); };
		$f{templates} = sub { return $data->template->templates(); };

		$f{stories_by_date} = sub {
			my $topic	= shift;
			my $num		= shift;
			my $offset	= shift;

			return map { $data->story($topic, $_) }
				$data->stories_by_date(
					$topic,
					num	=> $num,
					offset	=> $offset
				);
		};

		$f{search_stories} = sub {
			my $topic	= shift;
			my $string	= shift;

			return map { $data->story($topic, $_) }
				$data->search_stories($topic, $string);
		};

		$f{auth} = sub { return $data->auth(); };

		$f{login} = sub {
			my $user	= shift;
			my $pass	= shift;

			my $sid = undef;
			if ($sid = $data->login($user, $pass)) {
				$data->cgi->cookie("sid=$sid");
				$data->cgi->redirect('?t=INDEX');
			}

			return $sid;
		};

		$f{logout} = sub {
			$data->logout();
			$data->cgi->redirect('?t=INDEX');
		};

		$f{upload} = sub {
			my $dirnum	= shift;
			my $field	= shift;
			$data->cgi->upload($dirnum, $field);
		};

		$f{cgi} = $self->{cgi_vars};

		$self->{tt_data} = { %f };
	}

	return $self->{tt_data};
}


sub process {
	my $self	= shift;
	my $template	= shift;

	my $v = '';

	$self->{tt}->process($template, $self->_tt_data(), \$v)
		or die "TT: " . $self->{tt}->error();

	return $v;
}


1;
