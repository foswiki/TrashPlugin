# Plugin for Foswiki - The Free and Open Source Wiki, http://foswiki.org/
#
# TrashPlugin is Copyright (C) 2013-2024 Michael Daum http://michaeldaumconsulting.com
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU General Public License for more details, published at
# http://www.gnu.org/copyleft/gpl.html

package Foswiki::Plugins::TrashPlugin;

use strict;
use warnings;

use Foswiki::Func ();

our $VERSION = '4.10';
our $RELEASE = '%$RELEASE%';
our $SHORTDESCRIPTION = 'Maintain the Trash web';
our $LICENSECODE = '%$LICENSECODE%';
our $NO_PREFS_IN_TOPIC = 1;
our $core;

sub initPlugin {
  my ($topic, $web) = @_;

  Foswiki::Func::registerRESTHandler("cleanUp", sub { return getCore()->restCleanUp(@_); }, 
    authenticate => 1,
    validate => 0,
    http_allow => 'GET,POST',
  );

  my $trashWeb = ($web =~ /$Foswiki::cfg{TrashWebName}$/) ? $web : $web.'.'.$Foswiki::cfg{TrashWebName};
  if (Foswiki::Func::webExists($trashWeb)) {
    #print STDERR "setting TRASHWEB to $trashWeb\n";
    Foswiki::Func::setPreferencesValue("TRASHWEB", $trashWeb);
  }

  return 1;
}

sub finishPlugin {
  undef $core;
}

sub getCore {
  unless (defined $core) {
    require Foswiki::Plugins::TrashPlugin::Core;
    $core = new Foswiki::Plugins::TrashPlugin::Core();
  }

  return $core;
}


1;
