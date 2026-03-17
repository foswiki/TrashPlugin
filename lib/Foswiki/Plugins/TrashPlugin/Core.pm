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

package Foswiki::Plugins::TrashPlugin::Core;

use strict;
use warnings;

use Foswiki::Func ();
use Foswiki::Plugins ();
use Foswiki::Meta ();
use Foswiki::Time ();
use Foswiki::Sandbox ();
use Error qw (:try);
use CGI::Util ();

use constant TRACE => 0;

sub new {
  my $class = shift;

  my $this = bless({
      debug => $Foswiki::cfg{TrashPlugin}{Debug},
      expire => $Foswiki::cfg{TrashPlugin}{Expire} || '1M',
      excludeTopic => $Foswiki::cfg{TrashPlugin}{ExcludeTopic} || '^(WebAtom|WebRss|WebSearch|WebStatistics|WebChanges|WebHome|WebNotify|WebTopicList|WebIndex|WebLeftBar|WebSideBar|WebPreferences|TrashAttachment$',
      dry => 0,
      @_
    },
    $class
  );

  return $this;
}

sub restCleanUp {
  my ($this, $session, $subject, $verb, $response) = @_;

  throw Error::Simple("only admins may empty the trash") unless Foswiki::Func::isAnAdmin();

  my $request = $session->{request};

  $this->{dry} = Foswiki::Func::isTrue(scalar $request->param("dry"), 0);
  $this->{debug} = Foswiki::Func::isTrue(scalar $request->param("debug"), $this->{debug});

  my %params = (
    expire => $request->param("expire") // $this->{expire},
    mode => $request->param("mode") // "all",
    includetopic => $request->param("includetopic") // "",
    excludetopic => $request->param("excludetopic") // "",
    includeattachment => $request->param("includeattachment") // "",
    excludeattachment => $request->param("excludeattachment") // "",
  );

  $params{filenames}{$_} = 1 foreach $request->multi_param("filename");

  $params{expire} = "0s" if $params{expire} eq "0"; # special case: empty all
  $params{expire} =~ s/^[\-\+]?/-/;
  $params{expire} = CGI::Util::expire_calc($params{expire}); # SMELL: get rid of CGI::Util

  my $trashWebName = $Foswiki::cfg{TrashWebName} || 'Trash';
  my $web = $request->param("web");

  if ($web) {
    $this->cleanUpWeb($web, \%params);
  } else {
    foreach my $web (Foswiki::Func::getListOfWebs()) {
      next unless $web =~ /^(.*[\.\/])?$trashWebName$/;
      $this->cleanUpWeb($web, \%params);
    }
  }

  return;
}

sub cleanUpWeb {
  my ($this, $web, $params) = @_;

  return unless Foswiki::Func::webExists($web);

  $this->writeDebug("testing items in web $web older than ".Foswiki::Func::formatTime($params->{expire}).", mode=$params->{mode}");

  # cleaning up topics
  if ($params->{mode} =~ /^(all|topics?)$/) {
    foreach my $topic (Foswiki::Func::getTopicList($web)) {
      next if $topic =~ /$this->{excludeTopic}/;
      next if $topic eq 'WebStatistics'; # just to make sure
      next if $params->{includetopic} && $topic !~ /$params->{includetopic}/;
      next if $params->{excludetopic} && $topic =~ /$params->{excludetopic}/;
   
      my ($date) = Foswiki::Func::getRevisionInfo($web, $topic);
      next unless $date < $params->{expire};
   
      $this->writeDebug("expired - $date - topic $web.$topic");
      $this->removeFromStore($web, $topic);
    }
  }
 
  # cleaning up attachments
  # not using the Foswiki::Func api for performance reasons
  if ($params->{mode} =~ /^(all|attachments?)$/ && Foswiki::Func::topicExists($web, 'TrashAttachment')) {
    my $obj = Foswiki::Meta->load($Foswiki::Plugins::SESSION, $web, 'TrashAttachment');
    my $it = $obj->eachAttachment();
    foreach my $info ($obj->find("FILEATTACHMENT")) {
      my $attachment = $info->{name};
      next if $params->{filenames} && !$params->{filenames}{$attachment};
      next if $params->{includeattachment} && $attachment !~ /$params->{includeattachment}/;
      next if $params->{excludeattachment} && $attachment =~ /$params->{excludeattachment}/;

      if (!$info->{movedwhen} || $info->{movedwhen} < $params->{expire}) {
        $this->writeDebug("expired - $info->{movedwhen} - attachment $attachment");
      } else {
        $this->writeDebug("still fresh - attachment $attachment");
        next;
      }
   
      if ($obj->hasAttachment($attachment)) {
        $obj->removeFromStore($attachment) unless $this->{dry};
      } else {
        $this->writeDebug("woops, cannot delete attachment $attachment");
      }
    }
   
    # fixing META:FILEATTACHMENT list
    my $saveNeeded = 0;
    foreach my $info ($obj->find("FILEATTACHMENT")) {
      my $name = $info->{name};
      next if $obj->hasAttachment($name);
      #$this->writeDebug("attachment $name not found in trash ... cleaning up");
      $obj->remove("FILEATTACHMENT", $name) unless $this->{dry};
      $saveNeeded = 1;
    }
   
    if ($saveNeeded) {
      $this->writeDebug("fixing META in TrashAttachment");
      $obj->save() unless $this->{dry};
    }
  }

  # clean up trashed webs
  if ($params->{mode} =~ /^(all|webs?)$/) {
    foreach my $subWeb (Foswiki::Func::getListOfWebs(undef, $web)) {
      next unless Foswiki::Func::webExists($subWeb);

      $this->writeDebug("checking subWeb=$subWeb");
      my $webExpired = 1;
      foreach my $topic (Foswiki::Func::getTopicList($subWeb)) {
        next if $topic =~ /$this->{excludeTopic}/;
        next if $topic eq 'WebStatistics'; # just to make sure

        my ($date) = Foswiki::Func::getRevisionInfo($subWeb, $topic);
        if ($date >= $params->{expire}) {
          #$this->writeDebug("still fresh - topic $subWeb.$topic date=$date");
          $webExpired = 0;
          last;
        }
      }

      if ($webExpired) {
        $this->writeDebug("expired - web $subWeb");
        my $webObj = Foswiki::Meta->load($Foswiki::Plugins::SESSION, $subWeb);
        $webObj->removeFromStore();

        if (Foswiki::Func::getContext()->{FlexWebListPluginEnabled}) {
          require Foswiki::Plugins::FlexWebListPlugin;
          Foswiki::Plugins::FlexWebListPlugin::getCore()->removeWeb($subWeb);
        }

      } else {
        #$this->writeDebug("still fresh - web $subWeb");
      }
    }
  }

  if (Foswiki::Func::getContext()->{DBCachePluginEnabled}) {
    require Foswiki::Plugins::DBCachePlugin;
    Foswiki::Plugins::DBCachePlugin::getDB($web, 2);
  }
}

sub removeFromStore {
  my ($this, $web, $topic) = @_;

  # delete all attachments first
  my $obj = Foswiki::Meta->load($Foswiki::Plugins::SESSION, $web, $topic);

  foreach my $attachment (Foswiki::Func::getAttachmentList($web,$topic)) {
    #$this->writeDebug("deleting attachment $web.$topic $attachment");
    $attachment = Foswiki::Sandbox::untaintUnchecked($attachment); # SMELL: strange...these strings are tainted sometimes
    $obj->removeFromStore($attachment) unless $this->{dry};
  }

  #$this->writeDebug("deleting topic $web.$topic");
  $obj->removeFromStore() unless $this->{dry}; 
}

sub writeDebug {
  my ($this, $msg) = @_;

  print STDERR "TrashPlugin - $msg\n" if $this->{debug} || TRACE;
}

1;
