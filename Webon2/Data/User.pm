package Webon2::Data::User;

use base 'Webon2::Data::BASE';

sub fields { return qw(id username email password can_upload is_admin); }

1;
