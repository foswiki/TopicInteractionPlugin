# Plugin for Foswiki - The Free and Open Source Wiki, http://foswiki.org/
# 
# Copyright (C) 2010-2018 Michael Daum, http://michaeldaumconsulting.com
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

package Foswiki::Plugins::TopicInteractionPlugin::Action::MoveAttachment;

use strict;
use warnings;

use Error qw( :try );
use Foswiki::Func ();
use Foswiki::Plugins ();
use Foswiki::Meta ();
use Foswiki::Plugins::TopicInteractionPlugin::Action ();
our @ISA = ('Foswiki::Plugins::TopicInteractionPlugin::Action');
use constant DRY => 0; # toggle me

sub handle {
  my ($this, $response) = @_;

  my $params = $this->prepareAction($response);
  return unless $params;

  my $web = $params->{web};
  my $topic = $params->{topic};
  my $id = $params->{id};

  my $newWeb = $params->{newweb} || $web;
  my $newTopic = $params->{newtopic} || $topic;

  # check permissions
  my $wikiName = Foswiki::Func::getWikiName();
  unless (Foswiki::Func::checkAccessPermission(
    'CHANGE', $wikiName, undef, $topic, $web)) {
    $this->printJSONRPC($response, 102, "Access denied", $id);
    return;
  }

  # check existence
  ($newWeb, $newTopic) = Foswiki::Func::normalizeWebTopicName($newWeb, $newTopic);
  unless (Foswiki::Func::topicExists($newWeb, $newTopic)) {
    $this->printJSONRPC($response, 101, "Topic $newWeb.$newTopic does not exist", $id);
    return;
  }

  # check null move
  if ($newWeb eq $web && $newTopic eq $topic) {
    $this->printJSONRPC($response, 108, "Won't copy attachment to itself", $id);
    return;
  }

  # check permissions
  unless (Foswiki::Func::checkAccessPermission(
    'CHANGE', Foswiki::Func::getWikiName(), undef, $newTopic, $newWeb)) {
    $this->printJSONRPC($response, 102, "Access denied", $id);
    return;
  }

  # load source and target topics
  my $fromObj = Foswiki::Meta->load($Foswiki::Plugins::SESSION, $web, $topic); # web, topic already normalized
  my $toObj = Foswiki::Meta->load($Foswiki::Plugins::SESSION, $newWeb, $newTopic);

  my $error;
  foreach my $fileName (@{$params->{filenames}}) {
    next unless $fileName;
    $fileName = $this->sanitizeAttachmentName($fileName);

    unless ($fromObj->hasAttachment($fileName)) {
      $this->writeDebug("oops $fileName does not exist at $web.$topic");
      #$this->printJSONRPC($response, 104, "Attachment $fileName does not exist", $id);
      #last;
      next;
    }

    try {

      # from Foswiki::UI::Rename
      # look for a non-conflicting name in the trash web
      my $base = $fileName;
      my $ext = '';
      if ( $base =~ s/^(.*)(\..*?)$/$1_/ ) {
        $ext = $2;
      }
      my $toAttachment = $fileName;
      my $n = 1;
      while ($toObj->hasAttachment($toAttachment)) {
        $toAttachment = $base . $n . $ext;
        $n++;
      }

      $this->writeDebug("moving $web.$topic.$fileName to $newWeb.$newTopic.$toAttachment");

      $fromObj->moveAttachment($fileName, $toObj, new_name => $toAttachment) unless DRY;

    } catch Error::Simple with {
      $error = shift->{-text};
      $this->writeDebug("ERROR: $error");
    };

    last if $error;
  }

  if ($error) {
    $this->printJSONRPC($response, 1, $error, $id)
  } else {
    $this->printJSONRPC($response, 0, '', $id);
  }
}

1;
