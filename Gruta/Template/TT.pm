package Gruta::Template::TT;

use strict;
use warnings;

use Template;

sub new {
	my $class	= shift;
	my %args	= @_;

	my $t = bless( {}, $class );

	$t->{tt} = Template->new(
		'INCLUDE_PATH'	=>	$args{path},
		'INTERPOLATE'	=>	1,
		'TRIM'		=>	1
	) or die "TT: " . $Template::ERROR;

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


#sub link_to_topic { return '{-l|TOPIC|' . $_[1] . '}'; }
#sub link_to_story { return '{-l|STORY|' . $_[1] . '|' . $_[2] . '}'; }
#sub armor { $_[0]->{artemus}->armor($_[1]); }
#sub unarmor { $_[0]->{artemus}->unarmor($_[1]); }

sub _tt_data {
	my $self	= shift;

	if (not $self->{tt_data}) {
		my $data = $self->data();
		my %f = ();

		$f{topic} = sub { return $data->topic($_[0]); };
		$f{user} = sub { return $data->user($_[0]); };
		$f{story} = sub { return $data->story($_[0], $_[1]); };

		$f{get} = sub { return $_[0]->get($_[1]); };

		$f{topics} = sub { return $data->topics(); };
		$f{users} = sub { return $data->users(); };
		$f{renderers} = sub { return sort(keys(%{$data->{renderers_h}})); };

		$f{stories_by_date} = sub {
			my $topic	= shift;
			my $num		= shift;
			my $offset	= shift;

			return $data->stories_by_date(
				$topic,
				num	=> $num,
				offset	=> $offset
			);
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
		or die "TT: " . $Template::ERROR;

	return $v;
}

1;
