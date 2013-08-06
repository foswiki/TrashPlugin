# Plugin for Foswiki - The Free and Open Source Wiki, http://foswiki.org/
#
# TrashPlugin is Copyright (C) 2013 Michael Daum http://michaeldaumconsulting.com
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

sub new {
  my $class = shift;

  my $this = bless({
    debug => $Foswiki::cfg{TrashPlugin}{Debug},
    dry => 0,
    @_
  }, $class);

  return $this;
}

sub writeDebug {
  my ($this, $msg) = @_;

  print STDERR "$msg\n" if $this->{debug};
}

sub cleanUp {
  my ($this, $session, $subject, $verb, $response) = @_;

  throw Error::Simple("only admins may empty the trash") unless Foswiki::Func::isAnAdmin();

  my $request = $session->{request};

  $this->{dry} = Foswiki::Func::isTrue($request->param("dry"), 0);
  $this->{debug} = Foswiki::Func::isTrue($request->param("debug"), $this->{debug});

  my $expire = $request->param("expire");
  $expire = ($Foswiki::cfg{TrashPlugin}{Expire} || '1M') unless defined $expire;
  $expire =~ s/^\+\-//;
  $expire = "0s" if $expire eq "0"; # special case: empty all
  $expire = '-' . $expire;
  $this->{expire} = CGI::Util::expire_calc($expire);

  $this->writeDebug("testing items in web $Foswiki::cfg{TrashWebName} older than " . Foswiki::Time::formatTime($this->{expire}));

  my $web = $Foswiki::cfg{TrashWebName} || 'Trash';

  throw Error::Simple("$web does not exist") unless Foswiki::Func::webExists($web);

  # cleaning up topics
  foreach my $topic (Foswiki::Func::getTopicList($web)) {
    next if $topic =~ /^(WebAtom|WebRss|WebSearch.*|WebChanges|WebHome|WebNotify|WebTopicList|WebIndex|WebLeftBar|WebSideBar|WebPreferences|TrashAttachment)$/;
 
    my ($date) = Foswiki::Func::getRevisionInfo($web, $topic);
    next unless $date < $this->{expire};
 
    #$this->writeDebug("$web.$topic expired");#.Foswiki::Time::formatTime($date));
 
    $this->removeFromStore($web, $topic);
  }
 
  # cleaning up attachments
  # not using the Foswiki::Func api for performance reasons
  my $obj = Foswiki::Meta->load($Foswiki::Plugins::SESSION, $web, 'TrashAttachment');
  my $it = $obj->eachAttachment();
  while ($it->hasNext()) {
    my $attachment = $it->next();
    my $info = $obj->getAttachmentRevisionInfo($attachment);
    if ($info->{date} < $this->{expire}) {
      #$this->writeDebug("$attachment expired");
    } else {
      #$this->writeDebug("$attachment still fresh last modified ".Foswiki::Time::formatTime($info->{date}));
      next;
    }
 
    $this->writeDebug("deleting attachment $attachment");
    $attachment = Foswiki::Sandbox::untaintUnchecked($attachment);    # SMELL: strange...these strings are tainted sometimes
    $obj->removeFromStore($attachment) unless $this->{dry};
  }
 
  # fixing META:FILEATTACHMENT list
  my $saveNeeded = 0;
  foreach my $info ($obj->find("FILEATTACHMENT")) {
    my $name = $info->{name};
    next if $obj->hasAttachment($name);
    $this->writeDebug("attachment $name not found in trash ... cleaning up");
    $obj->remove("FILEATTACHMENT", $name) unless $this->{dry};
    $saveNeeded = 1;
  }
 
  if ($saveNeeded) {
    $this->writeDebug("fixing META in TrashAttachment");
    $obj->save() unless $this->{dry};
  }

  # clean up trashed webs
  foreach my $subWeb (Foswiki::Func::getListOfWebs(undef, $Foswiki::cfg{TrashWebName})) {
    my $webExpired = 1;
    foreach my $topic (Foswiki::Func::getTopicList($subWeb)) {
      my ($date) = Foswiki::Func::getRevisionInfo($subWeb, $topic);
      if ($date >= $this->{expire}) {
        $webExpired = 0;
        last;
      }
    }

    if ($webExpired) {
      $this->writeDebug("deleting web $subWeb");
      my $webObj = Foswiki::Meta->load($Foswiki::Plugins::SESSION, $subWeb);
      $webObj->removeFromStore();
    }
  }

  return "done";
}

sub removeFromStore {
  my ($this, $web, $topic) = @_;

  # delete all attachments first
  my $obj = Foswiki::Meta->load($Foswiki::Plugins::SESSION, $web, $topic);

  foreach my $attachment (Foswiki::Func::getAttachmentList($web,$topic)) {
    $this->writeDebug("deleting attachment $web.$topic $attachment");
    $attachment = Foswiki::Sandbox::untaintUnchecked($attachment); # SMELL: strange...these strings are tainted sometimes
    $obj->removeFromStore($attachment) unless $this->{dry};
  }

  $this->writeDebug("deleting topic $web.$topic");
  $obj->removeFromStore() unless $this->{dry}; 
}

1;
