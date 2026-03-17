# Plugin for Foswiki - The Free and Open Source Wiki, http://foswiki.org/
#
# TrashPlugin is Copyright (C) 2013-2026 Michael Daum http://michaeldaumconsulting.com
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

our $VERSION = '5.00';
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

  my $trashWeb = findTrashWeb($web); 
  Foswiki::Func::setPreferencesValue("TRASHWEB", $trashWeb) if $trashWeb;

  return 1;
}

sub findTrashWeb {
  my $web = shift;

  return $web if $web =~ /$Foswiki::cfg{TrashWebName}$/;

  my $trashWeb = $web.'.'.$Foswiki::cfg{TrashWebName};
  return $trashWeb if Foswiki::Func::webExists($trashWeb);

  if ($web =~ /^(.+)[\.\/].*?$/) {
    return findTrashWeb($1);  
  }

  return;
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
