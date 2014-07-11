#!/usr/bin/perl

my $PROTO_VERSION = '0.9';
my $SERVER_VERSION = '0.0';

use strict;
use warnings;

use File::Temp;

use Gruta;
use Gruta::Source::DBI;
use Gruta::Source::FS;
use Gruta::Renderer::Grutatxt;
use Gruta::Renderer::HTML;
use Gruta::Renderer::Text;

use threads;

sub gruta_obj
{
    my $src_str = shift;
    my $src;

	if ($src_str =~ /^dbi:/) {
		$src = Gruta::Source::DBI->new(string => $src_str);
	}
	else {
		$src = Gruta::Source::FS->new(path => $src_str);
	}

    my $g = Gruta->new(
        source => $src,
        renderers	=> [
            Gruta::Renderer::Grutatxt->new(),
            Gruta::Renderer::HTML->new(),
            Gruta::Renderer::HTML->new( valid_tags => undef ),
            Gruta::Renderer::Text->new(),
        ]
    );

    return $g;
}


sub usage
{
    print "grutad.pl - Grutad server in Perl\n\n";

    print "Usage:\n";
    print "grutad {src}\n\n";

    print "Where {src} is a Gruta source spec. Examples:\n\n";
    print " * /var/www/site_dir/var (FS type)\n";
    print " * dbi:SQLite:/var/www/site_dir/var/gruta.db (Perl DBI type)\n";

    exit 1;
}


sub chompr
{
    my $s = shift;

    if ($s) {
        $s =~ s/\r?\n$//;
    }

    return $s;
}


sub write_obj
{
    my $c = shift;
    my $h = shift;
    my $e = shift;

    my $o = $c->{o};

    if ($h) {
        print $o "OK Object follows\n";

        foreach my $k (keys(%{$h})) {
            my $v = $h->{$k} || '';

            if (ref(\$v) eq 'SCALAR') {
                $v =~ s/\n/\\n/g;

                if ($k eq '.' || $k =~ /^>/) {
                    $k = '>' . $k;
                }

                print $o $k, "\n";
                print $o $v, "\n";
            }
        }

        print $o ".\n";
    }
    else {
        print $o "ERROR ", $e, "\n";
    }
}


sub write_list
{
    my $c   = shift;
    my @l   = @_;
    my $o   = $c->{o};

    print $o "OK List follows\n";

    foreach my $e (@l) {
        my $t = ref($e);

        if ($t eq 'ARRAY') {
            print $o join(":", @{$e}), "\n";
        }
        else {
            if ($e eq '.' || $e =~ /^>/) {
                $e = '>' . $e;
            }

            print $o $e, "\n";
        }
    }
    print $o ".\n";
}


sub read_obj
{
    my $c = shift;
    my %h = ();

    my $i = $c->{i};
    my $o = $c->{o};

    print $o "OK Ready to receive object\n";

    while (my $k = <$i>) {
        $k = chompr($k);

        if ($k eq '.') {
            last;
        }

        $k =~ s/^>//;

        my $v = <$i> || '';
        $v = chompr($v);
        $v =~ s/\\n/\n/g;

        $h{$k} = $v;
    }

    return %h;
}


sub read_list
{
    my $c = shift;
    my @a = ();

    my $i = $c->{i};
    my $o = $c->{o};

    print $o "OK Ready to receive array\n";

    while (my $k = <$i>) {
        $k = chompr($k);

        if ($k eq '.') {
            last;
        }

        $k =~ s/^>//;

        push(@a, $k);
    }

    return @a;
}


sub write_result
{
    my $c = shift;
    my $e = shift;
    my $m = shift || 'Stored';

    my $o = $c->{o};

    if (!$e) {
        print $o "OK $m\n";
    }
    else {
        $e =~ s/\n/\\n/g;
        print $o "ERROR $e\n";
    }
}


my $dialog_ctl = {
    about               => [0,  sub {
                                    write_obj($_->[0], {
                                        proto_version   => $PROTO_VERSION,
                                        server_version  => $SERVER_VERSION,
                                        server_id       => 'grutad.pl'
                                    });
                                }
                            ],
    topics              => [0,  sub {
                                    my $c = shift;
                                    write_list($c, $c->{g}->source->topics());
                                }
                            ],
    users               => [0,  sub {
                                    my $c = shift;
                                    write_list($c, $c->{g}->source->users());
                                }
                            ],
    tags                => [0,  sub {
                                    my $c = shift;
                                    write_list($c, $c->{g}->source->tags());
                                }
                            ],
    templates           => [0,  sub {
                                    my $c = shift;
                                    write_list($c, $c->{g}->source->templates());
                                }
                            ],
    pending_comments    => [0,  sub {
                                    my $c = shift;
                                    write_list($c, $c->{g}->source->pending_comments());
                                }
                            ],
    comments            => [1,  sub {
                                    my ($c , $n) = @_;
                                    write_list($c, $c->{g}->source->comments($n));
                                }
                            ],
    stories             => [1,  sub {
                                    my ($c, $t) = @_;
                                    write_list($c, $c->{g}->source->stories($t));
                                }
                            ],
    story               => [2,  sub {
                                    my ($c, $t, $s) = @_;
                                    write_obj($c, $c->{g}->source->story($t, $s), "$t/$s story not found");
                                }
                            ],
    topic               => [1,  sub {
                                    my ($c, $i) = @_;
                                    write_obj($c, $c->{g}->source->topic($i), "$i topic not found");
                                }
                            ],
    user                => [1,  sub {
                                    my ($c, $i) = @_;
                                    write_obj($c, $c->{g}->source->user($i), "$i user not found");
                                }
                            ],
    template            => [1,  sub {
                                    my ($c, $i) = @_;
                                    write_obj($c, $c->{g}->source->template($i), "$i template not found");
                                }
                            ],
    store_story         => [-1, sub {
                                    my ($c, %a) = @_;

                                    my $o = Gruta::Data::Story->new(%a);

                                    eval {
                                        $c->{g}->render($o);
                                        $c->{g}->source->insert_story($o);
                                        $o->tags(split(/\s*,\s*/, $a{tags} || ''));
                                    };

                                    write_result($c, $@, $o->get('id'));
                                }
                            ],
    store_template      => [-1, sub {
                                    my ($c, %a) = @_;

                                    my $t = Gruta::Data::Template->new(%a);

                                    eval { $c->{g}->source->insert_template($t) };

                                    write_result($c, $@);
                                }
                            ],
    story_set           => [-1, sub {
                                    my ($c, %a) = @_;

                                    if ($a{topics}) {
                                        $a{topics} = [split(/\s*,\s*/, $a{topics})];
                                    }
                                    if ($a{tags}) {
                                        $a{tags} = [split(/\s*,\s*/, $a{tags})];
                                    }

                                    my @r;

                                    eval { @r = $c->{g}->source->story_set(%a); };

                                    if ($@) {
                                        write_result($c, $@);
                                    }
                                    else {
                                        write_list($c, @r);
                                    }
                                }
                            ],
};

sub dialog
{
    my $c = shift;

    my $g = $c->{g};
    my $i = $c->{i};
    my $o = $c->{o};

    for (;;) {
        my $k = <$i>;

        $k = chompr($k);

        if (!$k || $k eq 'bye') {
            last;
        }

        my $s = $dialog_ctl->{$k};

        if ($s) {
            my $ac  = $s->[0];
            my $f   = $s->[1];
            my $ok = 1;
            my @a;

            if ($ac < 0) {
                @a = read_obj($c);
            }
            elsif ($ac > 0) {
                @a = read_list($c);

                if (scalar(@a) < $ac) {
                    $ok = 0;
                }
            }
            else {
                @a = ();
            }

            if ($ok) {
                $f->($c, @a);
            }
        }
        else {
            print $o "ERROR $k command not found\n";
        }
    }
}


sub main
{
    my $stdio       = 0;
    my $port        = 8045;
    my $gruta_src   = undef;

    while (my $e = shift(@ARGV)) {
        if ($e eq '-s') {
            $stdio = 1;
        }
        elsif ($e eq '-p') {
            $port = shift(@ARGV);
        }
        elsif ($e !~ /^-/) {
            $gruta_src = $e;
        }
        else {
            print STDERR "Argument '$e' not recognized\n";
        }
    }

    if (!defined($gruta_src)) {
        usage();
    }

    my $gruta_obj = gruta_obj($gruta_src);

    if ($stdio) {
        my $o = {"g" => $gruta_obj, "i" => *STDIN, "o" => *STDOUT};
        threads->create(sub { dialog($o); })->join();
    }
    else {
        use IO::Socket::INET;

        my $s = IO::Socket::INET->new(
            Listen      => 5,
            LocalPort   => $port,
            Proto       => 'tcp',
            ReuseAddr   => 1
        ) or die "Cannot create socket ($!)";

        for (;;) {
            my $c = $s->accept();
            my $o = {
                g => $gruta_obj,
                i => $c,
                o => $c
            };

            threads->create(sub { dialog($o); $o->{i}->close(); });
        }
    }
}

##################

main();

exit 0;
