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

package Foswiki::Plugins::TopicInteractionPlugin::Action::ChangeProperties;

use strict;
use warnings;

use Error qw( :try );
use Foswiki::Func ();
use Foswiki::Plugins::TopicInteractionPlugin::Action ();
our @ISA = ('Foswiki::Plugins::TopicInteractionPlugin::Action');
use constant DRY => 0;    # toggle me

sub handle {
  my ($this, $response) = @_;

  my $params = $this->prepareAction($response);
  return unless $params;

  my $newFileName = $this->sanitizeAttachmentName($params->{filename});
  my $fileName = $this->sanitizeAttachmentName($params->{origfilename});

  my $web = $params->{web};
  my $topic = $params->{topic};
  my $id = $params->{id};

  unless (Foswiki::Func::attachmentExists($web, $topic, $fileName)) {
    $this->printJSONRPC($response, 104, "Attachment $fileName does not exist", $id);
    return;
  }

  # check permissions
  my $wikiName = Foswiki::Func::getWikiName();
  unless (Foswiki::Func::checkAccessPermission(
    'CHANGE', $wikiName, undef, $topic, $web)) {
    $this->printJSONRPC($response, 102, "Access denied", $id);
    return;
  }

  my $fileCreateLink = $params->{createlink} || '0';
  $fileCreateLink = $fileCreateLink eq 'on' ? 1 : 0;

  my $fileHide = $params->{hidefile};
  $fileHide = 'off' unless defined $fileHide;
  $fileHide = $fileHide eq 'on' ? 1 : 0;

  my $fileComment = $params->{filecomment};
  $fileComment = '' unless defined $fileComment;

  my $isThumbnail = $params->{isthumbnail};
  $isThumbnail = 'off' unless defined $isThumbnail && $isThumbnail eq 'on';
  $isThumbnail = $isThumbnail eq 'on' ? 1 : 0;

  $this->writeDebug("fileName=$fileName, newFileName=$newFileName, comment=$fileComment, hide=$fileHide, createlink=$fileCreateLink, isThumbnail=$isThumbnail");

  my $error;
  try {
    unless (DRY) {
      if ($newFileName ne $fileName) {
        Foswiki::Func::moveAttachment($web, $topic, $fileName, $web, $topic, $newFileName);
      }
      Foswiki::Func::saveAttachment(
        $web, $topic,
        $newFileName,
        {
          name => $newFileName,
          attachment => $newFileName,
          dontlog => !$Foswiki::cfg{Log}{upload},
          comment => $fileComment,
          hide => $fileHide,
          createlink => $fileCreateLink,
        }
      );

      my ($meta) = Foswiki::Func::readTopic($web, $topic);
      $this->setThumbnail($meta, $newFileName, $isThumbnail);
    }
  }
  catch Error::Simple with {
    $error = shift->{-text};
    $this->riteDebug("ERROR: $error");
  };

  if ($error) {
    $this->printJSONRPC($response, 1, $error, $id);
  } else {
    $this->printJSONRPC($response, 0, undef, $id);
  }
}

1;
